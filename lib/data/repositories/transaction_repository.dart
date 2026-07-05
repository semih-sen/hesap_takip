import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/currency/currency_service.dart';
import '../../core/currency/split_allocation.dart';
import '../../core/date/date_range.dart';
import '../../features/transactions/services/summary_data.dart';
import '../database/app_database.dart' as db;
import '../database/tables/enums.dart';
import '../database/app_database_provider.dart';
import '../database/daos/transaction_dao.dart';
import '../models/mappers/transaction_mapper.dart';
import '../models/transaction.dart';
import '../models/transaction_filter.dart';

part 'transaction_repository.g.dart';

/// A category to attach to a transaction, with an optional per-category split.
///
/// `allocatedAmountMinor == null` means the category covers the WHOLE
/// transaction. When any link in a set carries a non-null allocation, the set
/// is treated as a split and all its allocations are reconciled to sum exactly
/// to the transaction amount (the last absorbs the rounding remainder, §6).
class TransactionCategoryLink {
  const TransactionCategoryLink({
    required this.categoryId,
    this.allocatedAmountMinor,
  });

  final int categoryId;
  final int? allocatedAmountMinor;
}

/// Reactive data API for ledger transactions, returning DOMAIN [Transaction]
/// models. Feature-specific queries (summary, filtered list, partial-payment,
/// transfer) arrive with their own phases — this is the core read/write surface.
abstract interface class TransactionRepository {
  /// Transactions newest-first; narrowed to [walletId] when given.
  Stream<List<Transaction>> watchTransactions({int? walletId});

  /// Newest-first denormalized rows for the List scope, applying [filter]'s
  /// predicates in SQL and bounded to [limit] rows (growing-window pagination).
  Stream<List<TransactionListRowData>> watchTransactionRows(
    TransactionFilter filter, {
    required int limit,
  });

  /// Reactive 9-cell base-currency [SummaryData] over [walletIds] for [period]
  /// (Summary Card Refactor §A.4). [walletIds] empty ⇒ ALL non-archived wallets;
  /// archived wallets are always excluded (Flag A-3). Row-1 running balances
  /// include each effective wallet's `initialBalanceMinor` converted to base
  /// (Decision 1A / Flag A-4) plus completed transfer legs (Decision 2A); Row-2/3
  /// flows exclude transfers. All totals read the snapshotted `baseAmountMinor`
  /// (Flag A-2). [today] is injected for testability.
  Stream<SummaryData> watchSummary({
    required Set<int> walletIds,
    required DateRange period,
    required DateTime today,
  });

  /// The transaction with [id], or `null`.
  Future<Transaction?> findTransaction(int id);

  /// Both legs of the transfer [transferGroupId] (0 or 2 rows), as domain models.
  Future<List<Transaction>> transferLegs(String transferGroupId);

  /// The category links (id + optional split allocation) attached to [id].
  Future<List<TransactionCategoryLink>> categoryLinksFor(int id);

  /// Inserts [transaction] and returns the new row id.
  Future<int> createTransaction(Transaction transaction);

  /// Inserts [transaction] together with its category [links] atomically (one
  /// Drift transaction). Returns the new row id. Split allocations are validated
  /// per §5.1; a bad split throws [SplitAllocationException] and nothing is
  /// written.
  Future<int> createTransactionWithCategories({
    required Transaction transaction,
    required List<TransactionCategoryLink> links,
  });

  /// Replaces the stored transaction matching [transaction]'s id.
  Future<void> updateTransaction(Transaction transaction);

  /// Updates [transaction] and replaces its category [links] atomically.
  Future<void> updateTransactionWithCategories({
    required Transaction transaction,
    required List<TransactionCategoryLink> links,
  });

  /// Hard-deletes the transaction (cascades its category links).
  Future<void> deleteTransaction(int id);
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Transaction>> watchTransactions({int? walletId}) {
    final Stream<List<db.Transaction>> rows = walletId == null
        ? _db.transactionDao.watchAllTransactions()
        : _db.transactionDao.watchTransactionsForWallet(walletId);
    return rows.map((list) => list.map((row) => row.toDomain()).toList());
  }

  @override
  Stream<List<TransactionListRowData>> watchTransactionRows(
    TransactionFilter filter, {
    required int limit,
  }) => _db.transactionDao.watchTransactionRows(filter, limit: limit);

  static const CurrencyService _currency = CurrencyService();

  @override
  Stream<SummaryData> watchSummary({
    required Set<int> walletIds,
    required DateRange period,
    required DateTime today,
  }) async* {
    final String base = (await _db.settingsDao.getSettings()).baseCurrencyCode;

    // Resolve the effective, non-archived wallet set: empty selection ⇒ every
    // non-archived wallet; otherwise the selected non-archived wallets (F1/A-3).
    final List<db.Wallet> all = await _db.walletDao.getAllWallets();
    final List<db.Wallet> effective = all
        .where(
          (db.Wallet w) =>
              !w.isArchived &&
              (walletIds.isEmpty || walletIds.contains(w.id)),
        )
        .toList(growable: false);

    if (effective.isEmpty) {
      // No wallets in scope → an all-zero card (never an empty `IN ()`).
      yield SummaryData.zero(base);
      return;
    }

    // Row-1 initial balances converted to base (Decision 1A / Flag A-4): base
    // -currency wallets contribute directly; others convert at the latest cached
    // wallet→base rate (fallback 1.0 when none is cached).
    int initialBaseMinor = 0;
    for (final db.Wallet w in effective) {
      if (w.currencyCode == base) {
        initialBaseMinor += w.initialBalanceMinor;
        continue;
      }
      final db.ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
        baseCurrency: w.currencyCode,
        quoteCurrency: base,
        asOf: DateTime(9999, 12, 31),
      );
      final Decimal rate = cached?.rate ?? Decimal.one;
      initialBaseMinor += _currency.convertMinor(
        amountMinor: w.initialBalanceMinor,
        fromCode: w.currencyCode,
        toCode: base,
        rate: rate,
      );
    }

    final Set<int> effectiveIds = <int>{
      for (final db.Wallet w in effective) w.id,
    };

    // The aggregate SQL covers only non-parent rows (children/normal/transfers).
    // Each emission re-reads the pending bill-parents and folds their remaining
    // (converted to base in Dart) into Alacak/Borç/Devreden — kept reactive
    // because the aggregate re-emits on any `transactions` change (Flag B-5).
    yield* _db.transactionDao
        .watchSummaryBuckets(
          walletIds: effectiveIds,
          period: period,
          today: today,
        )
        .asyncMap((SummaryBuckets b) async {
          final List<db.Transaction> parents = await _db.transactionDao
              .getPendingBillParents(effectiveIds);
          final _ParentDeltas d = _foldPendingParents(parents, base, period);
          return _assemble(b, initialBaseMinor, base, d);
        });
  }

  /// Folds each pending bill-parent's REMAINING (planned − settled, in the
  /// parent's currency) into base-currency deltas for Alacak (receivable), Borç
  /// (payable) and Devreden (carried) per B.5. Completed parents and settled
  /// parents contribute nothing; children already carry the settled money.
  static _ParentDeltas _foldPendingParents(
    List<db.Transaction> parents,
    String base,
    DateRange period,
  ) {
    int receivable = 0;
    int payable = 0;
    int carried = 0;
    for (final db.Transaction p in parents) {
      final int remainingRow =
          (p.plannedAmountMinor ?? 0) - (p.settledAmountMinor ?? 0);
      if (remainingRow <= 0) {
        continue;
      }
      final int remainingBase = p.currencyCode == base
          ? remainingRow
          : _currency.convertMinor(
              amountMinor: remainingRow,
              fromCode: p.currencyCode,
              toCode: base,
              rate: p.exchangeRateToBase,
            );
      final bool isIncome = p.type == TransactionType.income;
      final bool inPeriod =
          !p.valueDate.isBefore(period.start) &&
          !p.valueDate.isAfter(period.end);
      if (inPeriod) {
        if (isIncome) {
          receivable += remainingBase;
        } else {
          payable += remainingBase;
        }
      }
      if (p.valueDate.isBefore(period.start)) {
        carried += isIncome ? remainingBase : -remainingBase;
      }
    }
    return _ParentDeltas(
      receivable: receivable,
      payable: payable,
      carriedNonTransfer: carried,
    );
  }

  /// Assembles the DAO buckets + converted initial balance + pending-parent
  /// deltas into the 9-cell [SummaryData] (Summary Card Refactor §A.4 / B.5).
  static SummaryData _assemble(
    SummaryBuckets b,
    int initialBaseMinor,
    String base,
    _ParentDeltas d,
  ) {
    final int receivable = b.receivableIncomeMinor + d.receivable;
    final int payable = b.payableExpenseMinor + d.payable;
    final int incomeTotal = b.collectedIncomeMinor + receivable;
    final int expenseTotal = b.paidExpenseMinor + payable;
    final int netBalance = incomeTotal - expenseTotal;
    final int carriedOver = initialBaseMinor +
        b.carriedNonTransferSignedMinor +
        d.carriedNonTransfer +
        b.carriedTransferSignedMinor;
    // Devredecek = Devreden + period net + in-period completed transfer legs, so
    // Devredecek(N) == Devreden(N+1) for contiguous periods (transfers are not
    // in `netBalance`, hence the explicit in-period transfer term — Decision 2A).
    final int carryForward =
        carriedOver + netBalance + b.inPeriodTransferSignedMinor;
    final int currentCash = initialBaseMinor + b.cashFlowSignedMinor;

    return SummaryData(
      baseCurrencyCode: base,
      carriedOverMinor: carriedOver,
      currentCashMinor: currentCash,
      carryForwardMinor: carryForward,
      incomeTotalMinor: incomeTotal,
      expenseTotalMinor: expenseTotal,
      netBalanceMinor: netBalance,
      collectedIncomeMinor: b.collectedIncomeMinor,
      receivableIncomeMinor: receivable,
      paidExpenseMinor: b.paidExpenseMinor,
      payableExpenseMinor: payable,
    );
  }

  @override
  Future<Transaction?> findTransaction(int id) async =>
      (await _db.transactionDao.getTransactionById(id))?.toDomain();

  @override
  Future<List<Transaction>> transferLegs(String transferGroupId) async {
    final List<db.Transaction> legs = await _db.transactionDao.getTransferLegs(
      transferGroupId,
    );
    return legs.map((db.Transaction l) => l.toDomain()).toList(growable: false);
  }

  @override
  Future<List<TransactionCategoryLink>> categoryLinksFor(int id) async {
    final List<db.TransactionCategory> rows = await _db.transactionDao
        .getCategoryLinksForTransaction(id);
    return rows
        .map(
          (db.TransactionCategory r) => TransactionCategoryLink(
            categoryId: r.categoryId,
            allocatedAmountMinor: r.allocatedAmountMinor,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> createTransaction(Transaction transaction) =>
      _db.transactionDao.createTransaction(transaction.toInsertCompanion());

  @override
  Future<int> createTransactionWithCategories({
    required Transaction transaction,
    required List<TransactionCategoryLink> links,
  }) {
    return _db.transaction<int>(() async {
      final int id = await _db.transactionDao.createTransaction(
        transaction.toInsertCompanion(),
      );
      await _db.transactionDao.replaceCategoryLinks(
        id,
        _linkCompanions(id, links, transaction.amount.minorUnits),
      );
      return id;
    });
  }

  @override
  Future<void> updateTransaction(Transaction transaction) =>
      _db.transactionDao.updateTransaction(transaction.toRow());

  @override
  Future<void> updateTransactionWithCategories({
    required Transaction transaction,
    required List<TransactionCategoryLink> links,
  }) {
    return _db.transaction<void>(() async {
      await _db.transactionDao.updateTransaction(transaction.toRow());
      await _db.transactionDao.replaceCategoryLinks(
        transaction.id,
        _linkCompanions(transaction.id, links, transaction.amount.minorUnits),
      );
    });
  }

  @override
  Future<void> deleteTransaction(int id) =>
      _db.transactionDao.deleteTransaction(id);

  /// Builds the junction-row companions for [links].
  ///
  /// Whole-transaction links (all `allocatedAmountMinor == null`) are stored as
  /// nulls. If ANY link carries an allocation the set is a split: every link
  /// must carry one, and the allocations are reconciled to sum exactly to
  /// [totalMinor] via [resolveSplitAllocations] (last absorbs the remainder).
  List<db.TransactionCategoriesCompanion> _linkCompanions(
    int transactionId,
    List<TransactionCategoryLink> links,
    int totalMinor,
  ) {
    if (links.isEmpty) {
      return const <db.TransactionCategoriesCompanion>[];
    }
    final bool isSplit = links.any(
      (TransactionCategoryLink l) => l.allocatedAmountMinor != null,
    );
    if (!isSplit) {
      return <db.TransactionCategoriesCompanion>[
        for (final TransactionCategoryLink l in links)
          db.TransactionCategoriesCompanion.insert(
            transactionId: transactionId,
            categoryId: l.categoryId,
            allocatedAmountMinor: const Value<int?>(null),
          ),
      ];
    }
    final List<int> raw = <int>[
      for (final TransactionCategoryLink l in links)
        // A partial split (some allocations missing) is invalid.
        l.allocatedAmountMinor ??
            (throw SplitAllocationException(totalMinor, 0)),
    ];
    final List<int> resolved = resolveSplitAllocations(totalMinor, raw);
    return <db.TransactionCategoriesCompanion>[
      for (int i = 0; i < links.length; i++)
        db.TransactionCategoriesCompanion.insert(
          transactionId: transactionId,
          categoryId: links[i].categoryId,
          allocatedAmountMinor: Value<int?>(resolved[i]),
        ),
    ];
  }
}

/// Base-currency deltas contributed by the pending bill-parents in scope,
/// folded into the summary buckets in Dart (B.5).
class _ParentDeltas {
  const _ParentDeltas({
    required this.receivable,
    required this.payable,
    required this.carriedNonTransfer,
  });

  /// Added to Alacak (pending income remaining, in period).
  final int receivable;

  /// Added to Borç (pending expense remaining, in period).
  final int payable;

  /// Signed remaining of pending parents dated before the period, added to
  /// Devreden (income +, expense −).
  final int carriedNonTransfer;
}

/// App-lifetime singleton transaction repository.
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    DriftTransactionRepository(ref.watch(appDatabaseProvider));
