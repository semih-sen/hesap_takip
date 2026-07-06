import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/app_database_provider.dart';

import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/services/balance_service.dart';

/// §D.5: an account's total balance is its non-archived wallets' balances,
/// each converted to the base currency at the latest cached rate, then summed.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> account() => db.accountDao.createAccount(
    AccountsCompanion.insert(
      name: 'Hesap',
      type: AccountType.bank,
      colorValue: 0xFF000000,
      iconCodePoint: 0xE000,
    ),
  );

  Future<int> wallet(
    int accountId, {
    required String code,
    int initial = 0,
    bool archived = false,
  }) => db.walletDao.createWallet(
    WalletsCompanion.insert(
      accountId: accountId,
      name: 'Cüzdan-$code',
      currencyCode: code,
      colorValue: 0xFF111111,
      iconCodePoint: 0xE001,
      initialBalanceMinor: Value(initial),
      isArchived: Value(archived),
    ),
  );

  Future<void> addCompleted(
    int walletId, {
    required int amountMinor,
    required String code,
    FlowDirection flow = FlowDirection.inflow,
  }) => db.transactionDao.createTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      type: flow == FlowDirection.inflow
          ? TransactionType.income
          : TransactionType.expense,
      flowDirection: flow,
      status: TransactionStatus.completed,
      amountMinor: amountMinor,
      currencyCode: code,
      exchangeRateToBase: Decimal.one,
      baseAmountMinor: amountMinor,
      valueDate: DateTime(2026, 7, 5),
    ),
  );

  test('per-currency DAO aggregate groups completed net + initial by currency',
      () async {
    final int a = await account();
    final int tryW = await wallet(a, code: 'TRY', initial: 1000);
    final int usdW = await wallet(a, code: 'USD', initial: 0);
    await addCompleted(tryW, amountMinor: 500, code: 'TRY'); // +500
    await addCompleted(
      tryW,
      amountMinor: 200,
      code: 'TRY',
      flow: FlowDirection.outflow,
    ); // -200
    await addCompleted(usdW, amountMinor: 1000, code: 'USD'); // +1000

    final Map<String, int> byCurrency = await db.walletDao
        .watchAccountBalanceByCurrency(a)
        .first;
    expect(byCurrency['TRY'], 1300); // 1000 + 500 - 200
    expect(byCurrency['USD'], 1000);
  });

  test('archived wallets are excluded from the aggregate', () async {
    final int a = await account();
    await wallet(a, code: 'TRY', initial: 1000);
    await wallet(a, code: 'TRY', initial: 9999, archived: true);

    final Map<String, int> byCurrency = await db.walletDao
        .watchAccountBalanceByCurrency(a)
        .first;
    expect(byCurrency['TRY'], 1000); // the archived 9999 is not counted
  });

  test('service converts each currency to base and sums the total', () async {
    // base = TRY (default seed). 1 USD = 30 TRY.
    await db.exchangeRateDao.insertRate(
      ExchangeRatesCompanion.insert(
        baseCurrency: 'USD',
        quoteCurrency: 'TRY',
        rate: Decimal.parse('30'),
        asOfDate: DateTime(2026, 1, 1),
      ),
    );
    final int a = await account();
    final int tryW = await wallet(a, code: 'TRY', initial: 1000); // 1000 TRY
    final int usdW = await wallet(a, code: 'USD', initial: 0);
    await addCompleted(usdW, amountMinor: 1000, code: 'USD'); // 10.00 USD

    final CurrencyService currency = CurrencyService(
      const [
  Currency(code: 'TRY', symbol: '₺', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'USD', symbol: '\$', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'EUR', symbol: '€', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),

],
    );
    final BalanceService svc = BalanceService(db, currency);
    final int total = await svc
        .watchAccountTotalBaseMinor(a, 'TRY')
        .first;
    // 1000 TRY + (1000 USD-minor = 10 USD * 30 = 300 TRY = 30000 minor)
    expect(total, 1000 + 30000);
    // silence the unused local
    expect(tryW, isPositive);
  });

  test('provider is reactive: adding a transaction updates the total', () async {
    final int a = await account();
    final int w = await wallet(a, code: 'TRY', initial: 0);
    final ProviderContainer container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Keep the stream alive.
    container.listen(accountTotalBalanceProvider(a), (_, _) {});
    expect(await container.read(accountTotalBalanceProvider(a).future), 0);

    await addCompleted(w, amountMinor: 2500, code: 'TRY');
    // Give the reactive Drift stream a moment to re-emit.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(accountTotalBalanceProvider(a).future), 2500);
  });
}
