import 'package:decimal/decimal.dart';
// Hide drift's column-expression helpers that collide with matcher's matchers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/mappers/account_mapper.dart';
import 'package:hesap_takip/data/models/mappers/category_mapper.dart';
import 'package:hesap_takip/data/models/mappers/exchange_rate_mapper.dart';
import 'package:hesap_takip/data/models/mappers/recurring_mapper.dart';
import 'package:hesap_takip/data/models/mappers/settings_mapper.dart';
import 'package:hesap_takip/data/models/mappers/transaction_mapper.dart';
import 'package:hesap_takip/data/models/mappers/wallet_mapper.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  // Inserts the minimal graph needed for a transaction/rule and returns the
  // wallet id.
  Future<int> seedWallet({String currencyCode = 'TRY'}) async {
    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Banka',
        type: AccountType.bank,
        colorValue: 0xFF102030,
        iconCodePoint: 0xE100,
      ),
    );
    return database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: currencyCode,
        colorValue: 0xFF203040,
        iconCodePoint: 0xE101,
      ),
    );
  }

  test('Account: row -> domain -> row preserves every field', () async {
    final int id = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Yatırım',
        type: AccountType.investment,
        colorValue: 0xFF445566,
        iconCodePoint: 0xE200,
        isArchived: const Value(true),
        sortOrder: const Value(7),
      ),
    );
    final db.Account row = (await database.accountDao.getAccountById(id))!;

    final domain = row.toDomain();
    expect(domain.name, 'Yatırım');
    expect(domain.type, AccountType.investment);
    expect(domain.isArchived, isTrue);
    expect(domain.sortOrder, 7);
    // Full round-trip equality (Drift data classes use value equality).
    expect(domain.toRow(), equals(row));
  });

  test('Wallet: currency composes into Money and round-trips', () async {
    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Banka',
        type: AccountType.bank,
        colorValue: 0xFF010203,
        iconCodePoint: 0xE300,
      ),
    );
    final int id = await database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Dolar',
        currencyCode: 'USD',
        initialBalanceMinor: const Value(150000),
        colorValue: 0xFF040506,
        iconCodePoint: 0xE301,
      ),
    );
    final db.Wallet row = (await database.walletDao.getWalletById(id))!;

    final domain = row.toDomain();
    expect(domain.currencyCode, 'USD');
    expect(domain.initialBalance.minorUnits, 150000);
    expect(domain.initialBalance.currencyCode, 'USD');
    expect(domain.toRow(), equals(row));
  });

  test('Category: parentId and fields round-trip', () async {
    final int parentId = await database.categoryDao.createCategory(
      db.CategoriesCompanion.insert(
        name: 'Üst',
        type: CategoryType.expense,
        colorValue: 0xFF111213,
        iconCodePoint: 0xE400,
      ),
    );
    final int childId = await database.categoryDao.createCategory(
      db.CategoriesCompanion.insert(
        name: 'Alt',
        type: CategoryType.expense,
        parentId: Value(parentId),
        colorValue: 0xFF141516,
        iconCodePoint: 0xE401,
      ),
    );
    final db.Category row = (await database.categoryDao.getCategoryById(
      childId,
    ))!;

    final domain = row.toDomain();
    expect(domain.parentId, parentId);
    expect(domain.toRow(), equals(row));
  });

  test('Transaction: Money, Decimal rate and date-only round-trip', () async {
    final int walletId = await seedWallet(currencyCode: 'USD');
    final Decimal rate = Decimal.parse('34.157');
    final DateTime valueDate = DateTime(2024, 2, 29); // leap day, date-only

    final int id = await database.transactionDao.createTransaction(
      db.TransactionsCompanion.insert(
        walletId: walletId,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 12345,
        currencyCode: 'USD',
        exchangeRateToBase: rate,
        baseAmountMinor: 421668,
        valueDate: valueDate,
        note: const Value('kira'),
        payee: const Value('Ev sahibi'),
      ),
    );
    final db.Transaction row = (await database.transactionDao
        .getTransactionById(id))!;

    final domain = row.toDomain();
    expect(domain.amount.minorUnits, 12345);
    expect(domain.amount.currencyCode, 'USD');
    expect(domain.currencyCode, 'USD');
    expect(domain.exchangeRateToBase, rate); // exact Decimal
    expect(domain.baseAmountMinor, 421668);
    expect(domain.valueDate, valueDate); // exact date-only
    expect(domain.note, 'kira');
    expect(domain.payee, 'Ev sahibi');
    expect(domain.toRow(), equals(row));
  });

  test('RecurringRule: date-only columns and Money round-trip', () async {
    final int walletId = await seedWallet();
    final int id = await database.recurringDao.createRule(
      db.RecurringRulesCompanion.insert(
        name: 'Aylık kira',
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        walletId: walletId,
        amountMinor: 500000,
        currencyCode: 'TRY',
        frequency: RecurrenceFrequency.monthly,
        byMonthDay: const Value(31),
        startDate: DateTime(2026, 1, 31),
        endDate: Value(DateTime(2026, 12, 31)),
        lastGeneratedDate: Value(DateTime(2026, 3, 31)),
        autoPost: const Value(true),
      ),
    );
    final db.RecurringRule row = (await database.recurringDao.getRuleById(id))!;

    final domain = row.toDomain();
    expect(domain.amount.minorUnits, 500000);
    expect(domain.amount.currencyCode, 'TRY');
    expect(domain.byMonthDay, 31);
    expect(domain.startDate, DateTime(2026, 1, 31));
    expect(domain.endDate, DateTime(2026, 12, 31));
    expect(domain.lastGeneratedDate, DateTime(2026, 3, 31));
    expect(domain.autoPost, isTrue);
    expect(domain.toRow(), equals(row));
  });

  test('ExchangeRateEntry: raw double rate round-trip', () async {
    const double rate = 34.123456;
    final int id = await database.exchangeRateDao.insertRate(
      db.ExchangeRatesCompanion.insert(
        baseCurrency: 'USD',
        quoteCurrency: 'TRY',
        rate: rate,
        asOfDate: DateTime(2026, 6, 1),
        source: const Value('manual'),
      ),
    );
    final db.ExchangeRate row = (await (database.select(
      database.exchangeRates,
    )..where((t) => t.id.equals(id))).getSingle());

    final domain = row.toDomain();
    expect(domain.rate, rate);
    expect(domain.source, 'manual');
    expect(domain.toRow(), equals(row));
  });

  test('Settings: seeded singleton maps to domain', () async {
    final db.AppSetting row = await database.settingsDao.getSettings();
    final domain = row.toDomain();
    expect(domain.baseCurrencyCode, 'TRY');
    expect(domain.firstDayOfWeek, 1);
  });
}
