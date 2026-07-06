import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/services/balance_service.dart';


import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';

void main() {
  late AppDatabase db;
  late BalanceService service;
  late CurrencyService currency;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    currency = CurrencyService(
      const [
  Currency(code: 'TRY', symbol: '₺', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'USD', symbol: '\$', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'EUR', symbol: '€', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),

],
    );
    service = BalanceService(db, currency);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedAccount() => db.accountDao.createAccount(
    AccountsCompanion.insert(
      name: 'Hesap',
      type: AccountType.bank,
      colorValue: 0xFF000000,
      iconCodePoint: 0xE000,
    ),
  );

  Future<int> seedWallet(
    int accountId, {
    String code = 'TRY',
    int initialMinor = 0,
  }) => db.walletDao.createWallet(
    WalletsCompanion.insert(
      accountId: accountId,
      name: 'Cüzdan',
      currencyCode: code,
      initialBalanceMinor: Value(initialMinor),
      colorValue: 0xFF111111,
      iconCodePoint: 0xE001,
    ),
  );

  Future<void> insertTxn(
    int walletId, {
    required FlowDirection flow,
    required TransactionStatus status,
    required int amountMinor,
    String code = 'TRY',
  }) => db.transactionDao.createTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      type: flow == FlowDirection.inflow
          ? TransactionType.income
          : TransactionType.expense,
      flowDirection: flow,
      status: status,
      amountMinor: amountMinor,
      currencyCode: code,
      exchangeRateToBase: Decimal.one,
      baseAmountMinor: amountMinor,
      valueDate: DateTime(2026, 7, 4),
    ),
  );

  test('initial-only balance equals the wallet initial balance', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId, initialMinor: 50000);
    expect(await service.watchWalletBalanceMinor(walletId).first, 50000);
  });

  test('completed inflow and outflow move the balance', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId, initialMinor: 50000);

    await insertTxn(
      walletId,
      flow: FlowDirection.inflow,
      status: TransactionStatus.completed,
      amountMinor: 20000,
    );
    expect(await service.watchWalletBalanceMinor(walletId).first, 70000);

    await insertTxn(
      walletId,
      flow: FlowDirection.outflow,
      status: TransactionStatus.completed,
      amountMinor: 5000,
    );
    expect(await service.watchWalletBalanceMinor(walletId).first, 65000);
  });

  test('non-completed rows do NOT move the balance', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId, initialMinor: 10000);

    for (final TransactionStatus status in <TransactionStatus>[
      TransactionStatus.pending,
      TransactionStatus.scheduled,
      TransactionStatus.cancelled,
    ]) {
      await insertTxn(
        walletId,
        flow: FlowDirection.inflow,
        status: status,
        amountMinor: 99999,
      );
    }
    expect(await service.watchWalletBalanceMinor(walletId).first, 10000);
  });

  test('two different-currency wallets stay independent', () async {
    final int accountId = await seedAccount();
    final int tryWallet = await seedWallet(accountId, initialMinor: 50000);
    final int usdWallet = await seedWallet(
      accountId,
      code: 'USD',
      initialMinor: 10000,
    );

    await insertTxn(
      usdWallet,
      flow: FlowDirection.inflow,
      status: TransactionStatus.completed,
      amountMinor: 3000,
      code: 'USD',
    );

    expect(await service.watchWalletBalanceMinor(tryWallet).first, 50000);
    expect(await service.watchWalletBalanceMinor(usdWallet).first, 13000);
  });

  test('the balance stream is reactive to inserts', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId, initialMinor: 50000);

    final Future<void> expectation = expectLater(
      service.watchWalletBalanceMinor(walletId),
      emitsThrough(70000),
    );
    await insertTxn(
      walletId,
      flow: FlowDirection.inflow,
      status: TransactionStatus.completed,
      amountMinor: 20000,
    );
    await expectation;
  });

  test('aggregated same-currency balance sums wallet balances', () async {
    final int accountId = await seedAccount();
    final int walletA = await seedWallet(accountId, initialMinor: 50000);
    final int walletB = await seedWallet(accountId, initialMinor: 30000);
    await insertTxn(
      walletA,
      flow: FlowDirection.outflow,
      status: TransactionStatus.completed,
      amountMinor: 5000,
    );

    final int total = await service.watchWalletsBalanceMinor(<int>{
      walletA,
      walletB,
    }).first;
    expect(total, 75000); // (50000 - 5000) + 30000

    expect(await service.watchWalletsBalanceMinor(<int>{}).first, 0);
  });
}
