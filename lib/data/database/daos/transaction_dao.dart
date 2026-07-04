import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/enums.dart';
import '../tables/transactions.dart';
import '../tables/wallets.dart';

part 'transaction_dao.g.dart';

/// Data access for [Transactions] and the [TransactionCategories] junction,
/// including the transaction↔category JOIN and the balance SQL aggregate.
///
/// [Wallets] is in the accessor so the balance aggregate can read
/// `initialBalanceMinor` and register `wallets` in `readsFrom` for reactivity.
@DriftAccessor(
  tables: [Transactions, TransactionCategories, Categories, Wallets],
)
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<int> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  /// Number of transactions referencing [walletId]. Used by the undo layer to
  /// pre-check whether a wallet is FK-deletable (a wallet with ledger rows is
  /// restricted and must be archived instead).
  Future<int> countForWallet(int walletId) async {
    final Expression<int> total = countAll(
      filter: transactions.walletId.equals(walletId),
    );
    final Selectable<int> query = (selectOnly(
      transactions,
    )..addColumns(<Expression<Object>>[total])).map((row) => row.read(total)!);
    return (await query.getSingle());
  }

  /// Reactive **balance** for one wallet, in that wallet's own minor units
  /// (PROJECT_PLAN §8.1):
  ///
  ///   `initialBalanceMinor + Σ(completed inflow) − Σ(completed outflow)`
  ///
  /// Only `completed` rows count (pending/scheduled/cancelled are excluded, so
  /// pending parent bills never move a balance). Transfers DO count — each leg
  /// carries an inflow/outflow. Enum filters bind the stored index (`.index`),
  /// so this is not fragile to hardcoded literals. `?1` is reused for the
  /// wallet id in both the sub-select and the WHERE.
  Stream<int> watchWalletBalanceMinor(int walletId) {
    return customSelect(
      'SELECT COALESCE((SELECT initial_balance_minor FROM wallets '
      'WHERE id = ?1), 0) + '
      'COALESCE(SUM(CASE WHEN flow_direction = ?2 '
      'THEN amount_minor ELSE -amount_minor END), 0) AS balance '
      'FROM transactions WHERE wallet_id = ?1 AND status = ?3',
      variables: <Variable>[
        Variable.withInt(walletId),
        Variable.withInt(FlowDirection.inflow.index),
        Variable.withInt(TransactionStatus.completed.index),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        transactions,
        wallets,
      },
    ).map((QueryRow row) => row.read<int>('balance')).watchSingle();
  }

  /// Reactive aggregated balance for a SET of wallets (sum of their individual
  /// balances). Meaningful only when every wallet shares a currency — mixing
  /// currencies into one integer is nonsensical, so cross-currency aggregation
  /// is deferred to Phase 7's base-currency `SummaryService`. Empty set → 0.
  Stream<int> watchWalletsBalanceMinor(Set<int> walletIds) {
    if (walletIds.isEmpty) {
      return Stream<int>.value(0);
    }
    final List<int> ids = walletIds.toList();
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<Variable> variables = <Variable>[
      ...ids.map(Variable.withInt), // wallets IN (...)
      Variable.withInt(FlowDirection.inflow.index), // CASE flow
      Variable.withInt(TransactionStatus.completed.index), // WHERE status
      ...ids.map(Variable.withInt), // transactions wallet_id IN (...)
    ];
    return customSelect(
      'SELECT COALESCE((SELECT SUM(initial_balance_minor) FROM wallets '
      'WHERE id IN ($placeholders)), 0) + '
      'COALESCE(SUM(CASE WHEN flow_direction = ? '
      'THEN amount_minor ELSE -amount_minor END), 0) AS balance '
      'FROM transactions WHERE status = ? AND wallet_id IN ($placeholders)',
      variables: variables,
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        transactions,
        wallets,
      },
    ).map((QueryRow row) => row.read<int>('balance')).watchSingle();
  }

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
