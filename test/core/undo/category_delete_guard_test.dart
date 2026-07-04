import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/category.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> seedCategory({
    String name = 'Kategori',
    int? parentId,
  }) => database.categoryDao.createCategory(
    db.CategoriesCompanion.insert(
      name: name,
      type: CategoryType.expense,
      parentId: Value(parentId),
      colorValue: 0xFF222222,
      iconCodePoint: 0xE002,
    ),
  );

  Category domainCategory(int id, {int? parentId}) => Category(
    id: id,
    name: 'Kategori',
    type: CategoryType.expense,
    parentId: parentId,
    colorValue: 0xFF222222,
    iconCodePoint: 0xE002,
    isArchived: false,
    sortOrder: 0,
  );

  DeleteCategoryAction actionFor(Category c) =>
      DeleteCategoryAction(category: c, label: 'silindi');

  test('canCommit is TRUE for a standalone, unreferenced category', () async {
    final int id = await seedCategory();
    expect(await actionFor(domainCategory(id)).canCommit(database), isTrue);
  });

  test('canCommit is FALSE when the category has children', () async {
    final int parentId = await seedCategory(name: 'Üst');
    await seedCategory(name: 'Alt', parentId: parentId);
    expect(
      await actionFor(domainCategory(parentId)).canCommit(database),
      isFalse,
    );
  });

  test('canCommit is FALSE when a transaction references the category',
      () async {
    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int walletId = await database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
    final int categoryId = await seedCategory();
    final int txnId = await database.transactionDao.createTransaction(
      db.TransactionsCompanion.insert(
        walletId: walletId,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 1000,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 1000,
        valueDate: DateTime(2026, 7, 5),
      ),
    );
    await database.transactionDao.addCategory(txnId, categoryId);

    expect(
      await actionFor(domainCategory(categoryId)).canCommit(database),
      isFalse,
    );
  });
}
