import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';

part 'balance_service.g.dart';

/// Wallet balance computation (PROJECT_PLAN §8.1).
///
/// A thin app-layer wrapper over the DAO's SQL aggregate — balances are computed
/// in SQLite (`initialBalanceMinor + Σ completed inflow − Σ completed outflow`),
/// never by summing a transaction stream in Dart. Values are minor units in the
/// wallet's own currency; formatting is the UI's job via `CurrencyService`.
class BalanceService {
  const BalanceService(this._db);

  final AppDatabase _db;

  /// Reactive balance for one wallet (its own minor units).
  Stream<int> watchWalletBalanceMinor(int walletId) =>
      _db.transactionDao.watchWalletBalanceMinor(walletId);

  /// Reactive aggregated balance for a set of wallets (same-currency only; see
  /// the DAO note). Empty set → 0.
  Stream<int> watchWalletsBalanceMinor(Set<int> walletIds) =>
      _db.transactionDao.watchWalletsBalanceMinor(walletIds);
}

/// App-lifetime singleton [BalanceService].
@Riverpod(keepAlive: true)
BalanceService balanceService(Ref ref) =>
    BalanceService(ref.watch(appDatabaseProvider));

/// Reactive balance (minor units) for a single wallet.
@riverpod
Stream<int> walletBalance(Ref ref, int walletId) =>
    ref.watch(balanceServiceProvider).watchWalletBalanceMinor(walletId);
