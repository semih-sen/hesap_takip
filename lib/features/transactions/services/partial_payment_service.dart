import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';
import '../../../data/database/tables/enums.dart';

part 'partial_payment_service.g.dart';

/// Attempting to pay more than a bill's remaining balance (both figures are in
/// the PARENT's currency, so the comparison is exact — Flag B-3). The UI offers
/// "cap to remaining" or "allow overpayment".
class OverpaymentFailure implements Exception {
  const OverpaymentFailure(this.remainingMinor, this.attemptedMinor);

  /// What is still owed, in the parent's currency minor units.
  final int remainingMinor;

  /// The attempted payment converted to the parent's currency minor units.
  final int attemptedMinor;

  @override
  String toString() =>
      'OverpaymentFailure(remaining: $remainingMinor, attempted: $attemptedMinor)';
}

/// Deleting a bill-parent that still has child payments without opting into a
/// cascade. The UI must require an explicit "delete bill and all its payments".
class ParentHasChildrenFailure implements Exception {
  const ParentHasChildrenFailure(this.childCount);

  final int childCount;

  @override
  String toString() => 'ParentHasChildrenFailure($childCount)';
}

/// Why a partial-payment request was rejected BEFORE any DB write.
enum PaymentValidationReason {
  nonPositiveAmount,
  missingWallet,
  archivedWallet,
  notPendingBill,
}

/// Typed failure thrown for an invalid partial-payment request, before a
/// `db.transaction` is opened, so nothing is ever partially written.
class PaymentValidationException implements Exception {
  const PaymentValidationException(this.reason);

  final PaymentValidationReason reason;

  @override
  String toString() => 'PaymentValidationException($reason)';
}

/// Robust bill/receivable settlement via a pending-parent / completed-child
/// ledger (PROJECT_PLAN §8.2 / Phase 9).
///
/// A **parent** (`pending`, `plannedAmountMinor` set) represents a bill or
/// receivable and NEVER moves money. Each **child** (`completed`,
/// `parentTransactionId` set) is a real money movement carrying its own base
/// snapshot. When fully settled the parent flips to `completed` but is still
/// excluded from all money math by `plannedAmountMinor IS NOT NULL` (Flag B-1),
/// so it is never counted on top of its children. Every multi-row write runs in
/// one `db.transaction`.
class PartialPaymentService {
  PartialPaymentService(this._db, this._currency);

  final AppDatabase _db;
  final CurrencyService _currency;

  /// Creates a pending parent bill/receivable and returns its transaction id.
  /// `amountMinor == plannedAmountMinor` at creation; `settledAmountMinor` is 0.
  Future<int> createBill({
    required int walletId,
    required TransactionType type,
    required int plannedAmountMinor,
    required DateTime valueDate,
    required List<int> categoryIds,
    String? payee,
    String? note,
  }) async {
    if (plannedAmountMinor <= 0) {
      throw const PaymentValidationException(
        PaymentValidationReason.nonPositiveAmount,
      );
    }
    if (type == TransactionType.transfer) {
      // A bill is only an income (receivable) or expense (payable).
      throw const PaymentValidationException(
        PaymentValidationReason.notPendingBill,
      );
    }
    final Wallet? wallet = await _db.walletDao.getWalletById(walletId);
    if (wallet == null) {
      throw const PaymentValidationException(
        PaymentValidationReason.missingWallet,
      );
    }
    if (wallet.isArchived) {
      throw const PaymentValidationException(
        PaymentValidationReason.archivedWallet,
      );
    }

    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;
    final Decimal rateToBase = await _rateToBase(
      wallet.currencyCode,
      base,
      valueDate,
    );
    final int baseAmountMinor = _convert(
      plannedAmountMinor,
      wallet.currencyCode,
      base,
      rateToBase,
    );

    return _db.transaction<int>(() async {
      final int parentId = await _db.transactionDao.createTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          type: type,
          flowDirection: type == TransactionType.income
              ? FlowDirection.inflow
              : FlowDirection.outflow,
          status: TransactionStatus.pending,
          amountMinor: plannedAmountMinor,
          currencyCode: wallet.currencyCode,
          exchangeRateToBase: rateToBase,
          baseAmountMinor: baseAmountMinor,
          valueDate: valueDate,
          payee: Value(payee),
          note: Value(note),
          plannedAmountMinor: Value(plannedAmountMinor),
          settledAmountMinor: const Value(0),
        ),
      );
      for (final int categoryId in categoryIds) {
        await _db.transactionDao.addCategory(parentId, categoryId);
      }
      return parentId;
    });
  }

  /// Applies a payment against the bill [parentId] and returns the new child id.
  /// [paymentAmountMinor] is in [sourceWalletId]'s currency; [rateToParentCurrency]
  /// converts source → parent currency (1 if same) and [rateToBase] source → base.
  Future<int> applyPayment({
    required int parentId,
    required int sourceWalletId,
    required int paymentAmountMinor,
    required Decimal rateToParentCurrency,
    required Decimal rateToBase,
    required DateTime valueDate,
    String? note,
    bool allowOverpayment = false,
  }) async {
    if (paymentAmountMinor <= 0) {
      throw const PaymentValidationException(
        PaymentValidationReason.nonPositiveAmount,
      );
    }
    final Wallet? source = await _db.walletDao.getWalletById(sourceWalletId);
    if (source == null) {
      throw const PaymentValidationException(
        PaymentValidationReason.missingWallet,
      );
    }
    if (source.isArchived) {
      throw const PaymentValidationException(
        PaymentValidationReason.archivedWallet,
      );
    }
    final Transaction? parent = await _db.transactionDao.getTransactionById(
      parentId,
    );
    if (parent == null ||
        parent.plannedAmountMinor == null ||
        parent.status != TransactionStatus.pending) {
      throw const PaymentValidationException(
        PaymentValidationReason.notPendingBill,
      );
    }

    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;
    final String sourceCurrency = source.currencyCode;
    final int planned = parent.plannedAmountMinor!;
    final int settled = parent.settledAmountMinor ?? 0;
    final int remaining = planned - settled;

    final int paymentInParent = _convert(
      paymentAmountMinor,
      sourceCurrency,
      parent.currencyCode,
      rateToParentCurrency,
    );
    if (paymentInParent > remaining && !allowOverpayment) {
      throw OverpaymentFailure(remaining, paymentInParent);
    }
    final int baseAmount = _convert(
      paymentAmountMinor,
      sourceCurrency,
      base,
      rateToBase,
    );
    final DateTime now = DateTime.now();
    final int newSettled = settled + paymentInParent;

    return _db.transaction<int>(() async {
      final int childId = await _db.transactionDao.createTransaction(
        TransactionsCompanion.insert(
          walletId: sourceWalletId,
          type: parent.type,
          flowDirection: parent.flowDirection,
          status: TransactionStatus.completed,
          amountMinor: paymentAmountMinor,
          currencyCode: sourceCurrency,
          exchangeRateToBase: rateToBase,
          baseAmountMinor: baseAmount,
          valueDate: valueDate,
          note: Value(note),
          parentTransactionId: Value(parent.id),
          // Children are never parents (planned NULL); their parent-currency
          // contribution is stored for exact reversal/recompute (Flag B-2).
          settledContribMinor: Value(paymentInParent),
        ),
      );
      await _db.transactionDao.updateTransaction(
        parent.copyWith(
          settledAmountMinor: Value(newSettled),
          status: newSettled >= planned
              ? TransactionStatus.completed
              : TransactionStatus.pending,
          updatedAt: now,
        ),
      );
      return childId;
    });
  }

  /// Reverses the child payment [childId]: restores its parent-currency
  /// contribution, reopens the parent to `pending` (even if it was `completed`),
  /// and deletes the child — atomically (Flag B-4).
  Future<void> reversePayment(int childId) async {
    final Transaction? child = await _db.transactionDao.getTransactionById(
      childId,
    );
    if (child == null || child.parentTransactionId == null) {
      return;
    }
    final Transaction? parent = await _db.transactionDao.getTransactionById(
      child.parentTransactionId!,
    );
    if (parent == null) {
      // Orphaned child (parent already gone) — just drop it.
      await _db.transactionDao.deleteTransaction(childId);
      return;
    }
    final int newSettled =
        (parent.settledAmountMinor ?? 0) - (child.settledContribMinor ?? 0);
    final DateTime now = DateTime.now();

    await _db.transaction(() async {
      await _db.transactionDao.updateTransaction(
        parent.copyWith(
          settledAmountMinor: Value(newSettled < 0 ? 0 : newSettled),
          status: TransactionStatus.pending,
          updatedAt: now,
        ),
      );
      await _db.transactionDao.deleteTransaction(childId);
    });
  }

  /// Deletes the bill [parentId]. With children present it throws
  /// [ParentHasChildrenFailure] unless [cascade] is set, in which case the
  /// children are removed first, then the parent, in one transaction.
  Future<void> deleteBill(int parentId, {bool cascade = false}) async {
    final int childCount = await _db.transactionDao.countChildren(parentId);
    if (childCount > 0 && !cascade) {
      throw ParentHasChildrenFailure(childCount);
    }
    await _db.transaction(() async {
      if (cascade) {
        await _db.transactionDao.deleteChildrenOf(parentId);
      }
      await _db.transactionDao.deleteTransaction(parentId);
    });
  }

  /// Self-heals the parent [parentId]: recomputes `settledAmountMinor` as the sum
  /// of its children's `settledContribMinor` and re-derives its status. Used by
  /// tests and a hidden maintenance action.
  Future<void> recomputeSettled(int parentId) async {
    final Transaction? parent = await _db.transactionDao.getTransactionById(
      parentId,
    );
    if (parent == null || parent.plannedAmountMinor == null) {
      return;
    }
    final int planned = parent.plannedAmountMinor!;
    final List<Transaction> children = await _db.transactionDao.getChildren(
      parentId,
    );
    int settled = 0;
    for (final Transaction c in children) {
      settled += c.settledContribMinor ?? 0;
    }
    final DateTime now = DateTime.now();
    await _db.transactionDao.updateTransaction(
      parent.copyWith(
        settledAmountMinor: Value(settled),
        status: settled >= planned
            ? TransactionStatus.completed
            : TransactionStatus.pending,
        updatedAt: now,
      ),
    );
  }

  /// Converts [amountMinor] from [from] to [to] at [rate], short-circuiting the
  /// identity case so no needless re-rounding happens when currencies match.
  int _convert(int amountMinor, String from, String to, Decimal rate) {
    if (from == to) {
      return amountMinor;
    }
    return _currency.convertMinor(
      amountMinor: amountMinor,
      fromCode: from,
      toCode: to,
      rate: rate,
    );
  }

  /// Latest cached [code]→[base] rate on or before [valueDate] (1 for the base
  /// currency, or when nothing is cached).
  Future<Decimal> _rateToBase(
    String code,
    String base,
    DateTime valueDate,
  ) async {
    if (code == base) {
      return Decimal.one;
    }
    final ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
      baseCurrency: code,
      quoteCurrency: base,
      asOf: AppDate.dateOnly(valueDate),
    );
    return cached?.rate ?? Decimal.one;
  }
}

/// App-lifetime singleton [PartialPaymentService].
@Riverpod(keepAlive: true)
PartialPaymentService partialPaymentService(Ref ref) =>
    PartialPaymentService(ref.watch(appDatabaseProvider), const CurrencyService());
