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

  Stream<List<Wallet>> watchAllWallets() => _ordered().watch();

  Stream<List<Wallet>> watchWalletsForAccount(int accountId) =>
      (_ordered()..where((t) => t.accountId.equals(accountId))).watch();

  SimpleSelectStatement<$WalletsTable, Wallet> _ordered() =>
      select(wallets)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
