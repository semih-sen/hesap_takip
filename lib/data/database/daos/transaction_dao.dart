import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/transactions.dart';

part 'transaction_dao.g.dart';

/// Data access for [Transactions] and the [TransactionCategories] junction,
/// including the transaction↔category JOIN.
@DriftAccessor(tables: [Transactions, TransactionCategories, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<int> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(Transaction entry) =>
      update(transactions).replace(entry);

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<Transaction?> getTransactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..orderBy([
            (t) =>
                OrderingTerm(expression: t.valueDate, mode: OrderingMode.desc),
          ]))
          .watch();

  Stream<List<Transaction>> watchTransactionsForWallet(int walletId) =>
      (select(transactions)
            ..where((t) => t.walletId.equals(walletId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.valueDate,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  /// Links a category to a transaction (`allocatedAmountMinor == null` means the
  /// category covers the whole transaction).
  Future<void> addCategory(
    int transactionId,
    int categoryId, {
    int? allocatedAmountMinor,
  }) {
    return into(transactionCategories).insert(
      TransactionCategoriesCompanion.insert(
        transactionId: transactionId,
        categoryId: categoryId,
        allocatedAmountMinor: Value(allocatedAmountMinor),
      ),
    );
  }

  /// JOIN query: the categories attached to [transactionId] via the junction
  /// table. This is the DAO-boundary join required by PROJECT_PLAN Phase 1.
  Stream<List<Category>> watchCategoriesForTransaction(int transactionId) =>
      _categoriesJoin(transactionId).watch();

  Future<List<Category>> getCategoriesForTransaction(int transactionId) =>
      _categoriesJoin(transactionId).get();

  Selectable<Category> _categoriesJoin(int transactionId) {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        select(transactionCategories).join([
          innerJoin(
            categories,
            categories.id.equalsExp(transactionCategories.categoryId),
          ),
        ])..where(transactionCategories.transactionId.equals(transactionId));
    return query.map((row) => row.readTable(categories));
  }
}
