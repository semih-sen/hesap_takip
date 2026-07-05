import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/currency/split_allocation.dart';
import '../database/app_database.dart' as db;
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

  /// The transaction with [id], or `null`.
  Future<Transaction?> findTransaction(int id);

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

  @override
  Future<Transaction?> findTransaction(int id) async =>
      (await _db.transactionDao.getTransactionById(id))?.toDomain();

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

/// App-lifetime singleton transaction repository.
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    DriftTransactionRepository(ref.watch(appDatabaseProvider));
