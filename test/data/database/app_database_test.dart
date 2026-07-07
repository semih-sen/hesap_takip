import 'package:decimal/decimal.dart';
// Hide drift's column-expression helpers that collide with matcher's matchers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // --- Fixture helpers -------------------------------------------------------

  Future<int> insertAccount({String name = 'Nakit'}) {
    return db.accountDao.createAccount(
      AccountsCompanion.insert(
        name: name,
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
  }

  Future<int> insertWallet(int accountId, {String currencyCode = 'TRY'}) {
    return db.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: currencyCode,
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
  }

  Future<int> insertCategory({
    String name = 'Test',
    CategoryType type = CategoryType.expense,
  }) {
    return db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: name,
        type: type,
        colorValue: 0xFF222222,
        iconCodePoint: 0xE002,
      ),
    );
  }

  Future<int> insertTransaction(
    int walletId, {
    DateTime? valueDate,
    Decimal? rate,
    int? recurringRuleId,
  }) {
    return db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 12345,
        currencyCode: 'TRY',
        exchangeRateToBase: rate ?? Decimal.one,
        baseAmountMinor: 12345,
        valueDate: valueDate ?? DateTime(2026, 7, 4),
        recurringRuleId: Value(recurringRuleId),
      ),
    );
  }

  Future<int> insertRule(int walletId) {
    return db.recurringDao.createRule(
      RecurringRulesCompanion.insert(
        name: 'Aylık kira',
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        walletId: walletId,
        amountMinor: 500000,
        currencyCode: 'TRY',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      ),
    );
  }

  // --- Migration, PRAGMA, seed ----------------------------------------------

  group('migration & seed', () {
    test('beforeOpen enables foreign_keys pragma', () async {
      final QueryRow row = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(row.data.values.first, 1);
    });

    test('seeds the singleton AppSettings row', () async {
      final AppSetting settings = await db.settingsDao.getSettings();
      expect(settings.id, 1);
      expect(settings.baseCurrencyCode, 'TRY');
      expect(settings.firstDayOfWeek, 1);
    });

    test('seeds the default Turkish categories', () async {
      final List<Category> categories = await db.categoryDao.getAllCategories();
      expect(categories.length, 15);
      expect(categories.where((c) => c.type == CategoryType.income).length, 5);
      expect(
        categories.where((c) => c.type == CategoryType.expense).length,
        10,
      );
      final Set<String> names = categories.map((c) => c.name).toSet();
      expect(names, containsAll(<String>['Maaş', 'Market', 'Kira']));
      // sortOrder preserves seed list order.
      expect(categories.first.sortOrder, 0);
    });
  });

  // --- CRUD round-trips ------------------------------------------------------

  group('CRUD round-trips', () {
    test('AccountDao create / read / update / delete', () async {
      final int id = await insertAccount(name: 'Banka');
      Account? account = await db.accountDao.getAccountById(id);
      expect(account, isNotNull);
      expect(account!.name, 'Banka');

      await db.accountDao.updateAccount(account.copyWith(name: 'Banka X'));
      account = await db.accountDao.getAccountById(id);
      expect(account!.name, 'Banka X');

      await db.accountDao.deleteAccount(id);
      expect(await db.accountDao.getAccountById(id), isNull);
    });

    test('WalletDao create / read / update / delete', () async {
      final int accountId = await insertAccount();
      final int id = await insertWallet(accountId, currencyCode: 'USD');
      Wallet? wallet = await db.walletDao.getWalletById(id);
      expect(wallet!.currencyCode, 'USD');

      await db.walletDao.updateWallet(wallet.copyWith(name: 'Dolar Cüzdanı'));
      wallet = await db.walletDao.getWalletById(id);
      expect(wallet!.name, 'Dolar Cüzdanı');

      await db.walletDao.deleteWallet(id);
      expect(await db.walletDao.getWalletById(id), isNull);
    });

    test('CategoryDao create / read / update / delete + watchByType', () async {
      final int id = await insertCategory(
        name: 'Kahve',
        type: CategoryType.expense,
      );
      final Category? category = await db.categoryDao.getCategoryById(id);
      expect(category!.name, 'Kahve');

      final List<Category> expenses = await db.categoryDao
          .watchByType(CategoryType.expense)
          .first;
      // 10 seeded expense categories + the one just inserted.
      expect(expenses.length, 11);

      await db.categoryDao.deleteCategory(id);
      expect(await db.categoryDao.getCategoryById(id), isNull);
    });

    test('TransactionDao create / read / update / delete', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final int id = await insertTransaction(walletId);

      Transaction? txn = await db.transactionDao.getTransactionById(id);
      expect(txn!.amountMinor, 12345);

      await db.transactionDao.updateTransaction(
        txn.copyWith(note: const Value('güncellendi')),
      );
      txn = await db.transactionDao.getTransactionById(id);
      expect(txn!.note, 'güncellendi');

      await db.transactionDao.deleteTransaction(id);
      expect(await db.transactionDao.getTransactionById(id), isNull);
    });

    test('RecurringDao create / read / delete', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final int id = await insertRule(walletId);

      final RecurringRule? rule = await db.recurringDao.getRuleById(id);
      expect(rule!.name, 'Aylık kira');
      expect(rule.interval, 1);
      expect(rule.isActive, isTrue);

      await db.recurringDao.deleteRule(id);
      expect(await db.recurringDao.getRuleById(id), isNull);
    });

    test('ExchangeRateDao insert + getLatestRate honours asOf', () async {
      await db.exchangeRateDao.insertRate(
        ExchangeRatesCompanion.insert(
          baseCurrency: 'USD',
          quoteCurrency: 'TRY',
          rate: 33.50,
          asOfDate: DateTime(2026, 1, 1),
        ),
      );
      await db.exchangeRateDao.insertRate(
        ExchangeRatesCompanion.insert(
          baseCurrency: 'USD',
          quoteCurrency: 'TRY',
          rate: 34.10,
          asOfDate: DateTime(2026, 6, 1),
        ),
      );

      final latest = await db.exchangeRateDao.getLatestRate(
        baseCurrency: 'USD',
        quoteCurrency: 'TRY',
        asOf: DateTime(2026, 3, 1),
      );
      // Only the 1 Jan rate is on/before 1 Mar.
      expect(latest!.rate, 33.50);
    });

    test('SettingsDao updates base currency in place', () async {
      await db.settingsDao.updateBaseCurrency('USD');
      final AppSetting settings = await db.settingsDao.getSettings();
      expect(settings.baseCurrencyCode, 'USD');
    });

    test('watchAllAccounts reflects inserts reactively', () async {
      expect(await db.accountDao.watchAllAccounts().first, isEmpty);
      await insertAccount();
      final List<Account> rows = await db.accountDao
          .watchAllAccounts()
          .firstWhere((List<Account> r) => r.isNotEmpty);
      expect(rows.length, 1);
    });
  });

  // --- JOIN ------------------------------------------------------------------

  group('transaction ↔ category JOIN', () {
    test('reads back categories attached via the junction table', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final int txnId = await insertTransaction(walletId);
      final int catA = await insertCategory(name: 'Yakıt');
      final int catB = await insertCategory(name: 'Otopark');

      await db.transactionDao.addCategory(txnId, catA);
      await db.transactionDao.addCategory(
        txnId,
        catB,
        allocatedAmountMinor: 5000,
      );

      final List<Category> linked = await db.transactionDao
          .getCategoriesForTransaction(txnId);
      expect(linked.map((c) => c.name).toSet(), <String>{'Yakıt', 'Otopark'});
    });
  });

  // --- Foreign keys: cascade + restrict -------------------------------------

  group('foreign key behaviour', () {
    test('deleting a transaction cascades its category links', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final int txnId = await insertTransaction(walletId);
      final int catId = await insertCategory();
      await db.transactionDao.addCategory(txnId, catId);

      expect((await db.select(db.transactionCategories).get()).length, 1);

      await db.transactionDao.deleteTransaction(txnId);
      expect(await db.select(db.transactionCategories).get(), isEmpty);
    });

    test(
      'a category referenced by a transaction cannot be hard-deleted',
      () async {
        final int accountId = await insertAccount();
        final int walletId = await insertWallet(accountId);
        final int txnId = await insertTransaction(walletId);
        final int catId = await insertCategory();
        await db.transactionDao.addCategory(txnId, catId);

        expect(
          () => db.categoryDao.deleteCategory(catId),
          throwsA(
            predicate(
              (Object? e) => e.toString().contains('FOREIGN KEY constraint'),
            ),
          ),
        );
      },
    );

    test('a wallet with transactions cannot be hard-deleted', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      await insertTransaction(walletId);

      expect(
        () => db.walletDao.deleteWallet(walletId),
        throwsA(
          predicate(
            (Object? e) => e.toString().contains('FOREIGN KEY constraint'),
          ),
        ),
      );
    });
  });

  // --- Converters ------------------------------------------------------------

  group('type converters', () {
    test('Decimal rate round-trips exactly', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final Decimal rate = Decimal.parse('1.234567');
      final int id = await insertTransaction(walletId, rate: rate);

      final Transaction txn = (await db.transactionDao.getTransactionById(id))!;
      expect(txn.exchangeRateToBase, rate);
    });

    test('date-only value round-trips and is stored as yyyy-MM-dd', () async {
      final int accountId = await insertAccount();
      final int walletId = await insertWallet(accountId);
      final DateTime leapDay = DateTime(2024, 2, 29);
      final int id = await insertTransaction(walletId, valueDate: leapDay);

      final Transaction txn = (await db.transactionDao.getTransactionById(id))!;
      expect(txn.valueDate, leapDay);

      final QueryRow raw = await db
          .customSelect(
            'SELECT value_date FROM transactions WHERE id = ?',
            variables: <Variable>[Variable.withInt(id)],
          )
          .getSingle();
      expect(raw.read<String>('value_date'), '2024-02-29');
    });
  });

  // --- Recurring idempotency guard ------------------------------------------

  group('recurring idempotency', () {
    test(
      'duplicate (recurringRuleId, valueDate) violates the unique index',
      () async {
        final int accountId = await insertAccount();
        final int walletId = await insertWallet(accountId);
        final int ruleId = await insertRule(walletId);
        final DateTime date = DateTime(2026, 2, 1);

        await insertTransaction(
          walletId,
          valueDate: date,
          recurringRuleId: ruleId,
        );

        expect(
          () => insertTransaction(
            walletId,
            valueDate: date,
            recurringRuleId: ruleId,
          ),
          throwsA(
            predicate(
              (Object? e) => e.toString().contains('UNIQUE constraint'),
            ),
          ),
        );
      },
    );

    test(
      'the partial index still allows rows with a null recurringRuleId',
      () async {
        final int accountId = await insertAccount();
        final int walletId = await insertWallet(accountId);
        final DateTime date = DateTime(2026, 2, 1);

        // Two ad-hoc (non-recurring) transactions on the same date are fine.
        await insertTransaction(walletId, valueDate: date);
        await insertTransaction(walletId, valueDate: date);

        expect(
          (await db.transactionDao.watchAllTransactions().first).length,
          2,
        );
      },
    );
  });
}
