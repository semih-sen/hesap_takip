import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/wallets.dart';

part 'wallet_dao.g.dart';

/// Data access for [Wallets].
@DriftAccessor(tables: [Wallets])
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

  SimpleSelectStatement<$WalletsTable, Wallet> _ordered() =>
      select(wallets)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
