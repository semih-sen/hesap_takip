import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/core/currency/money.dart';
import 'package:hesap_takip/core/currency/split_allocation.dart';
import 'package:hesap_takip/data/database/app_database.dart' hide Transaction;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/transaction.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/features/transactions/services/balance_service.dart';

void main() {
  late AppDatabase db;
  late DriftTransactionRepository repo;
  const CurrencyService currency = CurrencyService();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTransactionRepository(db);
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

  Future<int> seedCategory({String name = 'Kategori'}) =>
      db.categoryDao.createCategory(
        CategoriesCompanion.insert(
          name: name,
          type: CategoryType.expense,
          colorValue: 0xFF222222,
          iconCodePoint: 0xE002,
        ),
      );

  Transaction expenseTxn(
    int walletId, {
    int amountMinor = 100000,
    String code = 'TRY',
    Decimal? rate,
    int? baseAmountMinor,
  }) {
    final Decimal r = rate ?? Decimal.one;
    return Transaction(
      id: 0,
      walletId: walletId,
      type: TransactionType.expense,
      flowDirection: FlowDirection.outflow,
      status: TransactionStatus.completed,
      amount: Money(minorUnits: amountMinor, currencyCode: code),
      exchangeRateToBase: r,
      baseAmountMinor: baseAmountMinor ?? amountMinor,
      valueDate: DateTime(2026, 7, 5),
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
  }

  Future<int> countLinks(int transactionId) async {
    final rows = await db.transactionDao.getCategoryLinksForTransaction(
      transactionId,
    );
    return rows.length;
  }

  group('createTransactionWithCategories', () {
    test('writes the transaction and its links atomically', () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId);
      final int catA = await seedCategory(name: 'A');
      final int catB = await seedCategory(name: 'B');

      final int id = await repo.createTransactionWithCategories(
        transaction: expenseTxn(walletId),
        links: <TransactionCategoryLink>[
          TransactionCategoryLink(categoryId: catA),
          TransactionCategoryLink(categoryId: catB),
        ],
      );

      expect(await repo.findTransaction(id), isNotNull);
      expect(await countLinks(id), 2);
    });

    test('rolls back leaving NO transaction and NO orphan links on a bad '
        'split', () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId);
      final int catA = await seedCategory(name: 'A');
      final int catB = await seedCategory(name: 'B');

      // amountMinor = 1000 but the earlier allocation (1100) exceeds it → the
      // split is rejected, so the whole write must roll back.
      await expectLater(
        repo.createTransactionWithCategories(
          transaction: expenseTxn(walletId, amountMinor: 1000),
          links: <TransactionCategoryLink>[
            TransactionCategoryLink(categoryId: catA, allocatedAmountMinor: 1100),
            TransactionCategoryLink(categoryId: catB, allocatedAmountMinor: 50),
          ],
        ),
        throwsA(isA<SplitAllocationException>()),
      );

      expect(await db.transactionDao.watchAllTransactions().first, isEmpty);
      final int linkRows = await db
          .customSelect('SELECT COUNT(*) AS c FROM transaction_categories')
          .map((row) => row.read<int>('c'))
          .getSingle();
      expect(linkRows, 0);
    });

    test('a valid split is stored with the last absorbing the remainder',
        () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId);
      final int catA = await seedCategory(name: 'A');
      final int catB = await seedCategory(name: 'B');

      final int id = await repo.createTransactionWithCategories(
        transaction: expenseTxn(walletId, amountMinor: 1000),
        links: <TransactionCategoryLink>[
          TransactionCategoryLink(categoryId: catA, allocatedAmountMinor: 300),
          TransactionCategoryLink(categoryId: catB, allocatedAmountMinor: 401),
        ],
      );

      final rows = await db.transactionDao.getCategoryLinksForTransaction(id);
      final int sum = rows.fold<int>(
        0,
        (int acc, row) => acc + (row.allocatedAmountMinor ?? 0),
      );
      expect(sum, 1000);
    });
  });

  group('replaceCategoryLinks', () {
    test('is idempotent — repeating the same set keeps one row per category',
        () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId);
      final int catA = await seedCategory(name: 'A');
      final int id = await repo.createTransaction(expenseTxn(walletId));

      final links = <TransactionCategoriesCompanion>[
        TransactionCategoriesCompanion.insert(
          transactionId: id,
          categoryId: catA,
        ),
      ];
      await db.transactionDao.replaceCategoryLinks(id, links);
      await db.transactionDao.replaceCategoryLinks(id, links);

      expect(await countLinks(id), 1);
    });
  });

  group('rate snapshot', () {
    test('same currency ⇒ rate 1 and baseAmountMinor == amountMinor', () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId);

      final int amountMinor = 123456;
      final int baseAmountMinor = currency.convertMinor(
        amountMinor: amountMinor,
        fromCode: 'TRY',
        toCode: 'TRY',
        rate: Decimal.one,
      );
      final int id = await repo.createTransactionWithCategories(
        transaction: expenseTxn(
          walletId,
          amountMinor: amountMinor,
          rate: Decimal.one,
          baseAmountMinor: baseAmountMinor,
        ),
        links: const <TransactionCategoryLink>[],
      );

      final Transaction? txn = await repo.findTransaction(id);
      expect(txn!.exchangeRateToBase, Decimal.one);
      expect(txn.baseAmountMinor, amountMinor);
    });

    test('cross currency ⇒ baseAmountMinor matches convertMinor', () async {
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId, code: 'USD');
      final Decimal rate = Decimal.parse('30');
      final int amountMinor = 1000; // $10.00
      final int expectedBase = currency.convertMinor(
        amountMinor: amountMinor,
        fromCode: 'USD',
        toCode: 'TRY',
        rate: rate,
      );

      final int id = await repo.createTransactionWithCategories(
        transaction: expenseTxn(
          walletId,
          amountMinor: amountMinor,
          code: 'USD',
          rate: rate,
          baseAmountMinor: expectedBase,
        ),
        links: const <TransactionCategoryLink>[],
      );

      final Transaction? txn = await repo.findTransaction(id);
      expect(expectedBase, 30000);
      expect(txn!.baseAmountMinor, expectedBase);
      expect(txn.exchangeRateToBase, rate);
    });
  });

  group('balance reactivity', () {
    test('a completed expense lowers the balance; deleting restores it',
        () async {
      final BalanceService balances = BalanceService(db);
      final int accountId = await seedAccount();
      final int walletId = await seedWallet(accountId, initialMinor: 50000);
      final int catA = await seedCategory(name: 'A');

      final int id = await repo.createTransactionWithCategories(
        transaction: expenseTxn(walletId, amountMinor: 20000),
        links: <TransactionCategoryLink>[
          TransactionCategoryLink(categoryId: catA),
        ],
      );
      expect(await balances.watchWalletBalanceMinor(walletId).first, 30000);

      await repo.deleteTransaction(id);
      expect(await balances.watchWalletBalanceMinor(walletId).first, 50000);
    });
  });
}
