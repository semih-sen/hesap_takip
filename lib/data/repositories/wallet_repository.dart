import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/mappers/wallet_mapper.dart';
import '../models/wallet.dart';

part 'wallet_repository.g.dart';

/// Reactive data API for wallets, returning DOMAIN [Wallet] models.
abstract interface class WalletRepository {
  /// Wallets ordered by `sortOrder`; narrowed to [accountId] when given.
  Stream<List<Wallet>> watchWallets({int? accountId});

  /// The wallet with [id], or `null`.
  Future<Wallet?> findWallet(int id);

  /// Inserts [wallet] and returns the new row id.
  Future<int> createWallet(Wallet wallet);

  /// Replaces the stored wallet matching [wallet]'s id.
  Future<void> updateWallet(Wallet wallet);

  /// Soft-removes the wallet by setting `isArchived = true`.
  Future<void> archiveWallet(int id);

  /// Hard-deletes the wallet (blocked by FK if transactions reference it).
  Future<void> deleteWallet(int id);
}

class DriftWalletRepository implements WalletRepository {
  DriftWalletRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Wallet>> watchWallets({int? accountId}) {
    final Stream<List<db.Wallet>> rows = accountId == null
        ? _db.walletDao.watchAllWallets()
        : _db.walletDao.watchWalletsForAccount(accountId);
    return rows.map((list) => list.map((row) => row.toDomain()).toList());
  }

  @override
  Future<Wallet?> findWallet(int id) async =>
      (await _db.walletDao.getWalletById(id))?.toDomain();

  @override
  Future<int> createWallet(Wallet wallet) =>
      _db.walletDao.createWallet(wallet.toInsertCompanion());

  @override
  Future<void> updateWallet(Wallet wallet) =>
      _db.walletDao.updateWallet(wallet.toRow());

  @override
  Future<void> archiveWallet(int id) async {
    final db.Wallet? existing = await _db.walletDao.getWalletById(id);
    if (existing == null) {
      return;
    }
    await _db.walletDao.updateWallet(
      existing.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
  }

  @override
  Future<void> deleteWallet(int id) => _db.walletDao.deleteWallet(id);
}

/// App-lifetime singleton wallet repository.
@Riverpod(keepAlive: true)
WalletRepository walletRepository(Ref ref) =>
    DriftWalletRepository(ref.watch(appDatabaseProvider));
