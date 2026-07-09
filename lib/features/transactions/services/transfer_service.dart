import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/currency/currency_service.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/mappers/transaction_mapper.dart';
import '../../../data/models/transaction.dart' as domain;

part 'transfer_service.g.dart';

/// Why a transfer was rejected before any DB write (Flag B-4). The UI maps each
/// reason to a localized Turkish message.
enum TransferValidationReason {
  sameWallet,
  nonPositiveAmount,
  missingWallet,
  archivedWallet,
}

/// Typed failure thrown by [TransferService] for an invalid request. Thrown
/// BEFORE opening a `db.transaction`, so nothing is ever partially written.
class TransferValidationException implements Exception {
  const TransferValidationException(this.reason);

  final TransferValidationReason reason;

  @override
  String toString() => 'TransferValidationException($reason)';
}

/// Two-leg transfers, including cross-currency (PROJECT_PLAN §5.2 / Phase 8).
///
/// A transfer is two `completed`, `type=transfer` rows sharing a
/// `transferGroupId`: an OUTFLOW leg on the source wallet and an INFLOW leg on
/// the destination, each in its own wallet currency with its OWN base snapshot
/// (the two base figures may differ — Flag B-3 — which never distorts the
/// summary because transfers are excluded from its flow rows). Every create /
/// update / delete runs inside a single `db.transaction`, so a group is always
/// 0 or 2 rows (Flag B-1).
class TransferService {
  TransferService(this._db, this._currency);

  final AppDatabase _db;
  final CurrencyService _currency;

  static const Uuid _uuid = Uuid();

  /// Creates a transfer and returns its `transferGroupId`.
  ///
  /// [fromAmountMinor] is in the source wallet's currency, [toAmountMinor] in the
  /// destination's. For a same-currency transfer they are equal and [rate] is 1;
  /// cross-currency, [toAmountMinor] is typically `convertMinor(from, rate)` but
  /// the caller may override it. Each leg's base snapshot is taken from ITS OWN
  /// wallet currency → base at the latest cached rate on or before [valueDate].
  Future<String> createTransfer({
    required int fromWalletId,
    required int toWalletId,
    required int fromAmountMinor,
    required int toAmountMinor,
    required Decimal rate,
    required DateTime valueDate,
    String? note,
  }) async {
    final _TransferWallets w = await _validate(
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      fromAmountMinor: fromAmountMinor,
      toAmountMinor: toAmountMinor,
    );
    final String groupId = _uuid.v4();
    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;

    await _db.transaction(() async {
      await _insertLegs(
        groupId: groupId,
        base: base,
        wallets: w,
        fromAmountMinor: fromAmountMinor,
        toAmountMinor: toAmountMinor,
        valueDate: valueDate,
        note: note,
      );
    });
    return groupId;
  }

  /// Replaces both legs of [transferGroupId] atomically. Implemented as
  /// delete-both + insert-both inside one transaction so a currency change on
  /// either wallet re-snapshots each leg consistently (§B.2).
  Future<void> updateTransfer({
    required String transferGroupId,
    required int fromWalletId,
    required int toWalletId,
    required int fromAmountMinor,
    required int toAmountMinor,
    required Decimal rate,
    required DateTime valueDate,
    String? note,
  }) async {
    final _TransferWallets w = await _validate(
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      fromAmountMinor: fromAmountMinor,
      toAmountMinor: toAmountMinor,
    );
    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;

    await _db.transaction(() async {
      await _db.transactionDao.deleteTransferGroup(transferGroupId);
      await _insertLegs(
        groupId: transferGroupId,
        base: base,
        wallets: w,
        fromAmountMinor: fromAmountMinor,
        toAmountMinor: toAmountMinor,
        valueDate: valueDate,
        note: note,
      );
    });
  }

  /// Deletes BOTH legs of [transferGroupId] atomically. Balances recompute on
  /// their own (BalanceService counts only completed rows).
  Future<void> deleteTransfer(String transferGroupId) => _db.transaction(
    () => _db.transactionDao.deleteTransferGroup(transferGroupId),
  );

  /// Loads both legs of [transferGroupId] for the edit form, or null when the
  /// group does not resolve to exactly two legs. Returns the OUT leg (source) and
  /// IN leg (destination) as domain models.
  Future<({domain.Transaction from, domain.Transaction to})?> loadTransfer(
    String transferGroupId,
  ) async {
    final List<Transaction> legs = await _db.transactionDao.getTransferLegs(
      transferGroupId,
    );
    if (legs.length != 2) {
      return null;
    }
    final Transaction out = legs.firstWhere(
      (Transaction l) => l.flowDirection == FlowDirection.outflow,
    );
    final Transaction into = legs.firstWhere(
      (Transaction l) => l.flowDirection == FlowDirection.inflow,
    );
    return (from: out.toDomain(), to: into.toDomain());
  }

  /// Suggested `from → to` rate for the form, from the cache (latest on or
  /// before [valueDate]); 1 for a same-currency pair, or when none is cached.
  Future<Decimal> suggestRate(
    String fromCode,
    String toCode,
    DateTime valueDate,
  ) async {
    if (fromCode == toCode) {
      return Decimal.one;
    }
    final ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
      baseCurrency: fromCode,
      quoteCurrency: toCode,
      asOf: valueDate,
    );
    return cached?.rate ?? Decimal.one;
  }

  Future<void> _insertLegs({
    required String groupId,
    required String base,
    required _TransferWallets wallets,
    required int fromAmountMinor,
    required int toAmountMinor,
    required DateTime valueDate,
    required String? note,
  }) async {
    final Account? fromAccount = await _db.accountDao.getAccountById(
      wallets.from.accountId,
    );
    final Account? toAccount = await _db.accountDao.getAccountById(
      wallets.to.accountId,
    );
    final bool isCrossAccount = wallets.from.accountId != wallets.to.accountId;
    final String fromLabel = '${fromAccount?.name ?? '?'}/${wallets.from.name}';
    final String toLabel = '${toAccount?.name ?? '?'}/${wallets.to.name}';
    final String transferDetail = <String>[
      'Transfer sonucu oluşturuldu',
      'Gönderen: $fromLabel',
      'Alan: $toLabel',
    ].join('\n');
    final String? userNote = _stripTransferDetail(note);
    final String effectiveNote = userNote == null || userNote.isEmpty
        ? transferDetail
        : '$userNote\n$transferDetail';

    // OUT leg — source wallet, its own currency → base snapshot.
    final Decimal outRate = await _rateToBase(
      wallets.from.currencyCode,
      base,
      valueDate,
    );
    await _db.transactionDao.createTransaction(
      _leg(
        walletId: wallets.from.id,
        type: isCrossAccount
            ? TransactionType.expense
            : TransactionType.transfer,
        flow: FlowDirection.outflow,
        amountMinor: fromAmountMinor,
        currencyCode: wallets.from.currencyCode,
        rateToBase: outRate,
        baseAmountMinor: _toBase(
          fromAmountMinor,
          wallets.from.currencyCode,
          base,
          outRate,
        ),
        valueDate: valueDate,
        note: effectiveNote,
        groupId: groupId,
      ),
    );
    // IN leg — destination wallet, its own currency → base snapshot.
    final Decimal inRate = await _rateToBase(
      wallets.to.currencyCode,
      base,
      valueDate,
    );
    await _db.transactionDao.createTransaction(
      _leg(
        walletId: wallets.to.id,
        type: isCrossAccount
            ? TransactionType.income
            : TransactionType.transfer,
        flow: FlowDirection.inflow,
        amountMinor: toAmountMinor,
        currencyCode: wallets.to.currencyCode,
        rateToBase: inRate,
        baseAmountMinor: _toBase(
          toAmountMinor,
          wallets.to.currencyCode,
          base,
          inRate,
        ),
        valueDate: valueDate,
        note: effectiveNote,
        groupId: groupId,
      ),
    );
  }

  TransactionsCompanion _leg({
    required int walletId,
    required TransactionType type,
    required FlowDirection flow,
    required int amountMinor,
    required String currencyCode,
    required Decimal rateToBase,
    required int baseAmountMinor,
    required DateTime valueDate,
    required String? note,
    required String groupId,
  }) {
    return TransactionsCompanion.insert(
      walletId: walletId,
      type: type,
      flowDirection: flow,
      status: TransactionStatus.completed,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      exchangeRateToBase: rateToBase,
      baseAmountMinor: baseAmountMinor,
      valueDate: valueDate,
      note: Value(note),
      transferGroupId: Value(groupId),
    );
  }

  int _toBase(int amountMinor, String from, String base, Decimal rate) {
    if (from == base) {
      return amountMinor;
    }
    return _currency.convertMinor(
      amountMinor: amountMinor,
      fromCode: from,
      toCode: base,
      rate: rate,
    );
  }

  Future<Decimal> _rateToBase(
    String code,
    String base,
    DateTime onOrBefore,
  ) async {
    if (code == base) {
      return Decimal.one;
    }
    final ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
      baseCurrency: code,
      quoteCurrency: base,
      asOf: onOrBefore,
    );
    return cached?.rate ?? Decimal.one;
  }

  Future<_TransferWallets> _validate({
    required int fromWalletId,
    required int toWalletId,
    required int fromAmountMinor,
    required int toAmountMinor,
  }) async {
    if (fromWalletId == toWalletId) {
      throw const TransferValidationException(
        TransferValidationReason.sameWallet,
      );
    }
    if (fromAmountMinor <= 0 || toAmountMinor <= 0) {
      throw const TransferValidationException(
        TransferValidationReason.nonPositiveAmount,
      );
    }
    final Wallet? from = await _db.walletDao.getWalletById(fromWalletId);
    final Wallet? to = await _db.walletDao.getWalletById(toWalletId);
    if (from == null || to == null) {
      throw const TransferValidationException(
        TransferValidationReason.missingWallet,
      );
    }
    if (from.isArchived || to.isArchived) {
      throw const TransferValidationException(
        TransferValidationReason.archivedWallet,
      );
    }
    return _TransferWallets(from: from, to: to);
  }

  static String? _stripTransferDetail(String? note) {
    final String? trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final int marker = trimmed.indexOf('\nTransfer sonucu oluşturuldu');
    if (marker >= 0) {
      final String userNote = trimmed.substring(0, marker).trim();
      return userNote.isEmpty ? null : userNote;
    }
    if (trimmed.startsWith('Transfer sonucu oluşturuldu')) {
      return null;
    }
    final int legacyMarker = trimmed.indexOf('\nTransfer:');
    if (legacyMarker >= 0) {
      final String userNote = trimmed.substring(0, legacyMarker).trim();
      return userNote.isEmpty ? null : userNote;
    }
    if (trimmed.startsWith('Transfer:')) {
      return null;
    }
    return trimmed;
  }
}

/// The validated source/destination wallet rows for a transfer.
class _TransferWallets {
  const _TransferWallets({required this.from, required this.to});
  final Wallet from;
  final Wallet to;
}

/// App-lifetime singleton [TransferService].
@Riverpod(keepAlive: true)
TransferService transferService(Ref ref) => TransferService(
  ref.watch(appDatabaseProvider),
  ref.watch(currencyServiceProvider),
);
