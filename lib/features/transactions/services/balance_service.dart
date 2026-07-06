import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/currency/currency_service.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';
import '../../../data/repositories/settings_repository.dart';

part 'balance_service.g.dart';

/// Wallet balance computation (PROJECT_PLAN §8.1).
///
/// A thin app-layer wrapper over the DAO's SQL aggregate — balances are computed
/// in SQLite (`initialBalanceMinor + Σ completed inflow − Σ completed outflow`),
/// never by summing a transaction stream in Dart. Values are minor units in the
/// wallet's own currency; formatting is the UI's job via `CurrencyService`.
class BalanceService {
  const BalanceService(this._db, this._currency);

  final AppDatabase _db;
  final CurrencyService _currency;

  /// Reactive balance for one wallet (its own minor units).
  Stream<int> watchWalletBalanceMinor(int walletId) =>
      _db.transactionDao.watchWalletBalanceMinor(walletId);

  /// Reactive aggregated balance for a set of wallets (same-currency only; see
  /// the DAO note). Empty set → 0.
  Stream<int> watchWalletsBalanceMinor(Set<int> walletIds) =>
      _db.transactionDao.watchWalletsBalanceMinor(walletIds);

  /// Reactive total balance of [accountId]'s non-archived wallets, converted to
  /// [base] currency (§D.5). Each currency bucket from the DAO is converted at
  /// the latest cached rate on or before now (fallback `1`, same idiom as the
  /// summary / transfer snapshots), then summed. Same-currency buckets add
  /// directly. Re-subscribe with a new [base] to reflect a base-currency change.
  Stream<int> watchAccountTotalBaseMinor(int accountId, String base) async* {
    await for (final Map<String, int> byCurrency
        in _db.walletDao.watchAccountBalanceByCurrency(accountId)) {
      int total = 0;
      for (final MapEntry<String, int> entry in byCurrency.entries) {
        if (entry.key == base) {
          total += entry.value;
          continue;
        }
        final ExchangeRate? cached = await _db.exchangeRateDao.getLatestRate(
          baseCurrency: entry.key,
          quoteCurrency: base,
          asOf: DateTime.now(),
        );
        total += _currency.convertMinor(
          amountMinor: entry.value,
          fromCode: entry.key,
          toCode: base,
          rate: cached?.rate ?? Decimal.one,
        );
      }
      yield total;
    }
  }
}

/// App-lifetime singleton [BalanceService].
@Riverpod(keepAlive: true)
BalanceService balanceService(Ref ref) =>
    BalanceService(ref.watch(appDatabaseProvider), ref.watch(currencyServiceProvider));

/// Reactive balance (minor units) for a single wallet.
@riverpod
Stream<int> walletBalance(Ref ref, int walletId) =>
    ref.watch(balanceServiceProvider).watchWalletBalanceMinor(walletId);

/// Reactive base-currency total for one account (§D.5). Watches
/// [baseCurrencyProvider] so a base-currency change re-resolves the conversion.
@riverpod
Stream<int> accountTotalBalance(Ref ref, int accountId) {
  final String base = ref.watch(baseCurrencyProvider);
  return ref
      .watch(balanceServiceProvider)
      .watchAccountTotalBaseMinor(accountId, base);
}
