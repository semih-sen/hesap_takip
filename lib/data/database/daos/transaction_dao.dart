import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/enums.dart';
import '../tables/transactions.dart';
import '../tables/wallets.dart';

part 'transaction_dao.g.dart';

/// Denormalized read-model for one transaction-list row, produced by the joined
/// query in [TransactionDao.watchTransactionListRows] (transaction ⨝ wallet ⨝
/// primary category). It carries exactly what the bespoke row needs, avoiding an
/// N+1 of per-row category/wallet lookups. The application layer maps it to the
/// presentational `TransactionListRow` view-model.
class TransactionListRowData {
  const TransactionListRowData({
    required this.id,
    required this.walletId,
    required this.type,
    required this.flowDirection,
    required this.status,
    required this.amountMinor,
    required this.currencyCode,
    required this.valueDate,
    required this.walletName,
    this.note,
    this.payee,
    this.primaryCategoryName,
    this.primaryCategoryColorValue,
  });

  final int id;
  final int walletId;
  final TransactionType type;
  final FlowDirection flowDirection;
  final TransactionStatus status;
  final int amountMinor;
  final String currencyCode;
  final DateTime valueDate;
  final String walletName;
  final String? note;
  final String? payee;

  /// Name/color of the transaction's primary (lowest sortOrder) category, or
  /// null when the transaction has no category links.
  final String? primaryCategoryName;
  final int? primaryCategoryColorValue;
}

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

  /// Replaces ALL category links for [transactionId] with [links] — deletes the
  /// existing set, then inserts the new one. Idempotent for a given [links] set.
  /// Callers that also mutate the transaction row wrap this in one
  /// `db.transaction(...)` for atomicity (see `TransactionRepository`).
  Future<void> replaceCategoryLinks(
    int transactionId,
    List<TransactionCategoriesCompanion> links,
  ) async {
    await (delete(
      transactionCategories,
    )..where((t) => t.transactionId.equals(transactionId))).go();
    if (links.isEmpty) {
      return;
    }
    await batch((Batch b) => b.insertAll(transactionCategories, links));
  }

  /// Reactive, newest-first list of denormalized [TransactionListRowData] across
  /// ALL wallets. One query joins each transaction to its wallet and to its
  /// PRIMARY category (the linked category with the lowest `sortOrder`, then
  /// lowest id), so the list renders without per-row follow-up queries.
  ///
  /// `readsFrom` registers every table the projection depends on, so the stream
  /// re-emits when a transaction, its wallet, its category, or a link changes.
  Stream<List<TransactionListRowData>> watchTransactionListRows() {
    return customSelect(
      'SELECT t.id AS id, t.wallet_id AS wallet_id, t.type AS type, '
      't.flow_direction AS flow_direction, t.status AS status, '
      't.amount_minor AS amount_minor, t.currency_code AS currency_code, '
      't.value_date AS value_date, t.note AS note, t.payee AS payee, '
      'w.name AS wallet_name, '
      'pc.name AS category_name, pc.color_value AS category_color '
      'FROM transactions t '
      'JOIN wallets w ON w.id = t.wallet_id '
      'LEFT JOIN categories pc ON pc.id = ('
      '  SELECT tc.category_id FROM transaction_categories tc '
      '  JOIN categories c ON c.id = tc.category_id '
      '  WHERE tc.transaction_id = t.id '
      '  ORDER BY c.sort_order, c.id LIMIT 1'
      ') '
      'ORDER BY t.value_date DESC, t.id DESC',
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        transactions,
        wallets,
        categories,
        transactionCategories,
      },
    ).watch().map(
      (List<QueryRow> rows) => rows.map(_mapListRow).toList(growable: false),
    );
  }

  TransactionListRowData _mapListRow(QueryRow row) => TransactionListRowData(
    id: row.read<int>('id'),
    walletId: row.read<int>('wallet_id'),
    type: TransactionType.values[row.read<int>('type')],
    flowDirection: FlowDirection.values[row.read<int>('flow_direction')],
    status: TransactionStatus.values[row.read<int>('status')],
    amountMinor: row.read<int>('amount_minor'),
    currencyCode: row.read<String>('currency_code'),
    // value_date is stored as ISO 'yyyy-MM-dd' text (DateOnlyConverter).
    valueDate: DateTime.parse(row.read<String>('value_date')),
    walletName: row.read<String>('wallet_name'),
    note: row.read<String?>('note'),
    payee: row.read<String?>('payee'),
    primaryCategoryName: row.read<String?>('category_name'),
    primaryCategoryColorValue: row.read<int?>('category_color'),
  );

  /// Raw junction rows (category id + optional allocation) for [transactionId],
  /// used to prefill the edit form's category selection and splits.
  Future<List<TransactionCategory>> getCategoryLinksForTransaction(
    int transactionId,
  ) => (select(
    transactionCategories,
  )..where((t) => t.transactionId.equals(transactionId))).get();

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
