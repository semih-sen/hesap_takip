import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';
import '../../../data/database/tables/enums.dart';

part 'settlement_service.g.dart';

/// Why a settlement was rejected before any DB write.
enum SettlementFailureReason {
  nonPositiveAmount,
  overpayment,
  notPending,
  notSettleableType,
}

/// Typed failure for an invalid settlement request, thrown BEFORE opening a
/// `db.transaction` so nothing is ever partially written.
class SettlementFailure implements Exception {
  const SettlementFailure(this.reason);

  final SettlementFailureReason reason;

  @override
  String toString() => 'SettlementFailure($reason)';
}

/// What a [SettlementService.settle] call did, so the UI can undo it exactly:
/// a FULL settlement is reversed with [SettlementService.reopen]
/// ([originalValueDate]); a PARTIAL settlement is reversed with
/// [SettlementService.reverseSettlementChild] ([childId]).
class SettlementOutcome {
  const SettlementOutcome.full({
    required this.parentId,
    required DateTime this.originalValueDate,
  }) : wasFull = true,
       childId = null;

  const SettlementOutcome.partial({
    required this.parentId,
    required int this.childId,
  }) : wasFull = false,
       originalValueDate = null;

  final bool wasFull;
  final int parentId;
  final int? childId;
  final DateTime? originalValueDate;
}

/// Settle-in-place for date-derived pending items (Phase 9 rework §3).
///
/// A pending item's `amountMinor` IS its outstanding remainder. Settling the
/// FULL remaining realizes the item itself (it flips `completed`, dated today).
/// A PARTIAL settlement shrinks the parent by the paid amount and spawns a new
/// `completed` child (same wallet/currency/type/categories, dated today) — so
/// the total is counted exactly once with no parent-exclusion tricks. Only
/// `completed` rows move money (§8.1), so pending never double-counts.
///
/// The child inherits the parent's wallet, currency, and snapshotted
/// `exchangeRateToBase`; base amounts are CONSERVED by subtracting the child's
/// base from the parent's rather than re-converting the remainder (Flag E-2).
/// Every method runs in a single `db.transaction` (Flag E-7).
class SettlementService {
  SettlementService(this._db, this._currency);

  final AppDatabase _db;
  final CurrencyService _currency;

  /// Settles [paymentAmountMinor] (in the parent's wallet currency) against the
  /// pending item [transactionId]. `P == remaining` ⇒ full; `P < remaining` ⇒
  /// partial. [paymentDate] defaults to today.
  Future<SettlementOutcome> settle({
    required int transactionId,
    required int paymentAmountMinor,
    DateTime? paymentDate,
  }) async {
    final DateTime payDate = AppDate.dateOnly(paymentDate ?? AppDate.today());
    final Transaction? parent = await _db.transactionDao.getTransactionById(
      transactionId,
    );
    if (parent == null || parent.status != TransactionStatus.pending) {
      throw const SettlementFailure(SettlementFailureReason.notPending);
    }
    if (parent.type == TransactionType.transfer) {
      throw const SettlementFailure(SettlementFailureReason.notSettleableType);
    }
    final int remaining = parent.amountMinor;
    if (paymentAmountMinor <= 0) {
      throw const SettlementFailure(SettlementFailureReason.nonPositiveAmount);
    }
    if (paymentAmountMinor > remaining) {
      throw const SettlementFailure(SettlementFailureReason.overpayment);
    }
    final DateTime now = DateTime.now();

    // FULL settlement — realize the item itself today.
    if (paymentAmountMinor == remaining) {
      final DateTime originalValueDate = parent.valueDate;
      await _db.transaction(() async {
        await _db.transactionDao.updateTransaction(
          parent.copyWith(
            status: TransactionStatus.completed,
            valueDate: payDate,
            updatedAt: now,
          ),
        );
      });
      return SettlementOutcome.full(
        parentId: parent.id,
        originalValueDate: originalValueDate,
      );
    }

    // PARTIAL settlement — shrink the parent, spawn a completed child today.
    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;
    final int childBase = parent.currencyCode == base
        ? paymentAmountMinor
        : _currency.convertMinor(
            amountMinor: paymentAmountMinor,
            fromCode: parent.currencyCode,
            toCode: base,
            rate: parent.exchangeRateToBase.toDouble(),
          );

    late final int childId;
    await _db.transaction(() async {
      childId = await _db.transactionDao.createTransaction(
        TransactionsCompanion.insert(
          walletId: parent.walletId,
          type: parent.type,
          flowDirection: parent.flowDirection,
          status: TransactionStatus.completed,
          amountMinor: paymentAmountMinor,
          currencyCode: parent.currencyCode,
          exchangeRateToBase: parent.exchangeRateToBase,
          baseAmountMinor: childBase,
          valueDate: payDate,
          note: Value(parent.note),
          payee: Value(parent.payee),
          parentTransactionId: Value(parent.id),
        ),
      );
      // The child carries the parent's categories as whole-amount links (E-6).
      final List<TransactionCategory> links = await _db.transactionDao
          .getCategoryLinksForTransaction(parent.id);
      for (final TransactionCategory link in links) {
        await _db.transactionDao.addCategory(childId, link.categoryId);
      }
      // Conserve base exactly: subtract the child's base, never re-convert (E-2).
      await _db.transactionDao.updateTransaction(
        parent.copyWith(
          amountMinor: remaining - paymentAmountMinor,
          baseAmountMinor: parent.baseAmountMinor - childBase,
          updatedAt: now,
        ),
      );
    });
    return SettlementOutcome.partial(parentId: parent.id, childId: childId);
  }

  /// Undoes a PARTIAL settlement: restores the parent's amount + base, reopens
  /// it to `pending`, and deletes the child (its category links cascade). Atomic.
  Future<void> reverseSettlementChild(int childId) async {
    final Transaction? child = await _db.transactionDao.getTransactionById(
      childId,
    );
    if (child == null || child.parentTransactionId == null) {
      return;
    }
    final Transaction? parent = await _db.transactionDao.getTransactionById(
      child.parentTransactionId!,
    );
    final DateTime now = DateTime.now();
    await _db.transaction(() async {
      if (parent != null) {
        await _db.transactionDao.updateTransaction(
          parent.copyWith(
            amountMinor: parent.amountMinor + child.amountMinor,
            baseAmountMinor: parent.baseAmountMinor + child.baseAmountMinor,
            status: TransactionStatus.pending,
            updatedAt: now,
          ),
        );
      }
      await _db.transactionDao.deleteTransaction(childId);
    });
  }

  /// Undoes a FULL settlement: reopens [transactionId] to `pending` and restores
  /// its [originalValueDate] (captured before the settle). Atomic.
  Future<void> reopen({
    required int transactionId,
    required DateTime originalValueDate,
  }) async {
    final Transaction? txn = await _db.transactionDao.getTransactionById(
      transactionId,
    );
    if (txn == null) {
      return;
    }
    await _db.transaction(() async {
      await _db.transactionDao.updateTransaction(
        txn.copyWith(
          status: TransactionStatus.pending,
          valueDate: AppDate.dateOnly(originalValueDate),
          updatedAt: DateTime.now(),
        ),
      );
    });
  }
}

/// App-lifetime singleton [SettlementService].
@Riverpod(keepAlive: true)
SettlementService settlementService(Ref ref) =>
    SettlementService(ref.watch(appDatabaseProvider), ref.watch(currencyServiceProvider));
