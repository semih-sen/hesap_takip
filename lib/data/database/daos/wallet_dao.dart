import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/transactions.dart';
import '../tables/wallets.dart';

part 'wallet_dao.g.dart';

/// Data access for [Wallets].
///
/// [Transactions] is in the accessor so [watchAccountBalanceByCurrency] can
/// aggregate completed ledger rows and register `transactions` for reactivity.
@DriftAccessor(tables: [Wallets, Transactions])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  Future<int> createWallet(WalletsCompanion entry) =>
      into(wallets).insert(entry);

  Future<bool> updateWallet(Wallet entry) => update(wallets).replace(entry);

  Future<int> deleteWallet(int id) =>
      (delete(wallets)..where((t) => t.id.equals(id))).go();

  Future<Wallet?> getWalletById(int id) =>
      (select(wallets)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Number of wallets under [accountId]. Used by the undo layer to pre-check
  /// whether an account is FK-deletable (an account with wallets is restricted
  /// and must be archived, or its wallets removed first).
  Future<int> countForAccount(int accountId) async {
    final Expression<int> total = countAll(
      filter: wallets.accountId.equals(accountId),
    );
    final Selectable<int> query = (selectOnly(
      wallets,
    )..addColumns(<Expression<Object>>[total])).map((row) => row.read(total)!);
    return query.getSingle();
  }

  Stream<List<Wallet>> watchAllWallets() => _ordered().watch();

  /// One-shot read of every wallet (used by the summary's initial-balance
  /// resolution, which needs `initialBalanceMinor` / currency / archived flag).
  Future<List<Wallet>> getAllWallets() => _ordered().get();

  Stream<List<Wallet>> watchWalletsForAccount(int accountId) =>
      (_ordered()..where((t) => t.accountId.equals(accountId))).watch();

  /// Reactive per-currency balance across [accountId]'s NON-archived wallets
  /// (§D.5): `code → Σ(initialBalanceMinor + completed inflow − outflow)`,
  /// grouped by wallet currency. A currency with no wallets is simply absent
  /// (never a 0 entry). The service converts these to one base-currency total;
  /// summing across currencies at this layer would be nonsensical.
  Stream<Map<String, int>> watchAccountBalanceByCurrency(int accountId) {
    return customSelect(
      'SELECT w.currency_code AS code, '
      'SUM(w.initial_balance_minor + COALESCE(txn.net, 0)) AS total '
      'FROM wallets w '
      'LEFT JOIN ('
      '  SELECT wallet_id, '
      '    SUM(CASE WHEN flow_direction = ? '
      '      THEN amount_minor ELSE -amount_minor END) AS net '
      '  FROM transactions WHERE status = ? GROUP BY wallet_id'
      ') txn ON txn.wallet_id = w.id '
      'WHERE w.account_id = ? AND w.is_archived = 0 '
      'GROUP BY w.currency_code',
      variables: <Variable>[
        Variable.withInt(FlowDirection.inflow.index),
        Variable.withInt(TransactionStatus.completed.index),
        Variable.withInt(accountId),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        wallets,
        transactions,
      },
    ).watch().map(
      (List<QueryRow> rows) => <String, int>{
        for (final QueryRow r in rows)
          r.read<String>('code'): r.read<int>('total'),
      },
    );
  }

  SimpleSelectStatement<$WalletsTable, Wallet> _ordered() =>
      select(wallets)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
