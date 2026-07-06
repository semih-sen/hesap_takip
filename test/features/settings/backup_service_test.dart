import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/settings/services/backup_service.dart';

/// §E.6: the JSON backup round-trips the whole DB (including Decimal columns,
/// self-references, and multi-currency data), and rejects invalid envelopes.
void main() {
  late AppDatabase source;

  setUp(() => source = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => source.close());

  /// Seeds a rich dataset touching every table: two accounts, multi-currency
  /// wallets, categories, a completed txn with a category link, a pending parent
  /// with a partial-settlement child (self-reference), a transfer pair, a
  /// recurring rule + its generated txn, and a cached exchange rate.
  Future<void> seedRich(AppDatabase db) async {
    final int acc = await db.accountDao.createAccount(
      AccountsCompanion.insert(
        name: 'Banka',
        type: AccountType.bank,
        colorValue: 0xFF112233,
        iconCodePoint: 0xE000,
      ),
    );
    final int tryW = await db.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: acc,
        name: 'TRY',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
        initialBalanceMinor: const Value(5000),
      ),
    );
    final int usdW = await db.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: acc,
        name: 'USD',
        currencyCode: 'USD',
        colorValue: 0xFF222222,
        iconCodePoint: 0xE002,
      ),
    );
    final int cat = await db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: 'Kira',
        type: CategoryType.expense,
        colorValue: 0xFF333333,
        iconCodePoint: 0xE003,
      ),
    );
    // Completed txn + category link.
    final int txn = await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: tryW,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 1200,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 1200,
        valueDate: DateTime(2026, 7, 5),
      ),
    );
    await db.transactionDao.addCategory(txn, cat);
    // Pending parent + partial-settlement child (self-reference).
    final int parent = await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: tryW,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.pending,
        amountMinor: 700,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 700,
        valueDate: DateTime(2026, 8, 15),
      ),
    );
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: tryW,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 300,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 300,
        valueDate: DateTime(2026, 7, 6),
        parentTransactionId: Value(parent),
      ),
    );
    // Transfer pair sharing a group id.
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: tryW,
        type: TransactionType.transfer,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 900,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 900,
        valueDate: DateTime(2026, 7, 7),
        transferGroupId: const Value('grp-1'),
      ),
    );
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: usdW,
        type: TransactionType.transfer,
        flowDirection: FlowDirection.inflow,
        status: TransactionStatus.completed,
        amountMinor: 30,
        currencyCode: 'USD',
        exchangeRateToBase: Decimal.parse('30'),
        baseAmountMinor: 900,
        valueDate: DateTime(2026, 7, 7),
        transferGroupId: const Value('grp-1'),
      ),
    );
    // Recurring rule + category link + a generated txn.
    final int rule = await db.recurringDao.createRule(
      RecurringRulesCompanion.insert(
        name: 'Abonelik',
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        walletId: tryW,
        amountMinor: 150,
        currencyCode: 'TRY',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 10),
      ),
    );
    await db.recurringDao.addCategory(rule, cat);
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: tryW,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.pending,
        amountMinor: 150,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 150,
        valueDate: DateTime(2026, 2, 10),
        recurringRuleId: Value(rule),
      ),
    );
    // Cached exchange rate (Decimal).
    await db.exchangeRateDao.insertRate(
      ExchangeRatesCompanion.insert(
        baseCurrency: 'USD',
        quoteCurrency: 'TRY',
        rate: Decimal.parse('30.55'),
        asOfDate: DateTime(2026, 1, 1),
      ),
    );
  }

  Future<int> count(AppDatabase db, String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  test('export → import into a fresh DB round-trips every table exactly',
      () async {
    await seedRich(source);
    final String json = await BackupService(source).exportToJson();

    final AppDatabase target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    await BackupService(target).importFromJson(json);

    for (final String t in <String>[
      'accounts',
      'wallets',
      'categories',
      'transactions',
      'transaction_categories',
      'recurring_rules',
      'recurring_rule_categories',
      'exchange_rates',
    ]) {
      expect(
        await count(target, t),
        await count(source, t),
        reason: 'row count mismatch for $t',
      );
    }

    // Decimal + key fields survive precisely.
    final ExchangeRate rate = await (target.select(
      target.exchangeRates,
    )).getSingle();
    expect(rate.rate, Decimal.parse('30.55'));

    // The self-referencing child still points at its parent.
    final List<Transaction> children = await (target.select(
      target.transactions,
    )..where((t) => t.parentTransactionId.isNotNull())).get();
    expect(children.length, 1);
    expect(children.single.amountMinor, 300);

    // The transfer pair kept its shared group id.
    final List<Transaction> legs = await (target.select(
      target.transactions,
    )..where((t) => t.transferGroupId.equals('grp-1'))).get();
    expect(legs.length, 2);
  });

  test('importing wipes pre-existing data first (replace, not merge)', () async {
    await seedRich(source);
    final String json = await BackupService(source).exportToJson();

    final AppDatabase target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    // Pre-seed the target with unrelated data.
    await target.accountDao.createAccount(
      AccountsCompanion.insert(
        name: 'Silinecek',
        type: AccountType.cash,
        colorValue: 0xFF999999,
        iconCodePoint: 0xE099,
      ),
    );

    await BackupService(target).importFromJson(json);

    final List<Account> accounts = await target.select(target.accounts).get();
    expect(accounts.map((Account a) => a.name), <String>['Banka']);
  });

  test('base currency setting round-trips', () async {
    await source.settingsDao.updateBaseCurrency('EUR');
    final String json = await BackupService(source).exportToJson();
    final AppDatabase target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    await BackupService(target).importFromJson(json);
    expect((await target.settingsDao.getSettings()).baseCurrencyCode, 'EUR');
  });

  group('envelope validation', () {
    test('non-JSON is rejected', () async {
      await expectLater(
        BackupService(source).importFromJson('not json'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('missing schemaVersion is rejected', () async {
      await expectLater(
        BackupService(source).importFromJson('{"accounts": []}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('a newer schemaVersion is rejected', () async {
      await expectLater(
        BackupService(source).importFromJson('{"schemaVersion": 999}'),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
