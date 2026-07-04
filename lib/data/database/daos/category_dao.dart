import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/enums.dart';
import '../tables/recurring.dart';
import '../tables/transactions.dart';

part 'category_dao.g.dart';

/// Data access for [Categories].
///
/// The junction tables ([TransactionCategories], [RecurringRuleCategories]) are
/// in the accessor so [isReferenced] can check whether a category is used before
/// the undo layer allows a hard delete (referenced categories are archived
/// instead, PROJECT_PLAN Phase 4).
@DriftAccessor(
  tables: [Categories, TransactionCategories, RecurringRuleCategories],
)
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<int> createCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Future<Category?> getCategoryById(int id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Number of categories whose `parentId` is [parentId] (its direct children).
  /// A category with children cannot be hard-deleted (it would orphan them).
  Future<int> childCount(int parentId) async {
    final Expression<int> total = countAll(
      filter: categories.parentId.equals(parentId),
    );
    final Selectable<int> query = (selectOnly(
      categories,
    )..addColumns(<Expression<Object>>[total])).map((row) => row.read(total)!);
    return query.getSingle();
  }

  /// Whether [categoryId] is referenced by any transaction or recurring-rule
  /// link, i.e. it participates in history and must not be hard-deleted.
  Future<bool> isReferenced(int categoryId) async {
    final int txnLinks = await _countTxnLinks(categoryId);
    if (txnLinks > 0) {
      return true;
    }
    return (await _countRuleLinks(categoryId)) > 0;
  }

  Future<int> _countTxnLinks(int categoryId) async {
    final Expression<int> total = countAll(
      filter: transactionCategories.categoryId.equals(categoryId),
    );
    final Selectable<int> query = (selectOnly(
      transactionCategories,
    )..addColumns(<Expression<Object>>[total])).map((row) => row.read(total)!);
    return query.getSingle();
  }

  Future<int> _countRuleLinks(int categoryId) async {
    final Expression<int> total = countAll(
      filter: recurringRuleCategories.categoryId.equals(categoryId),
    );
    final Selectable<int> query = (selectOnly(
      recurringRuleCategories,
    )..addColumns(<Expression<Object>>[total])).map((row) => row.read(total)!);
    return query.getSingle();
  }

  Future<List<Category>> getAllCategories() => _ordered().get();

  Stream<List<Category>> watchAllCategories() => _ordered().watch();

  Stream<List<Category>> watchByType(CategoryType type) =>
      (_ordered()..where((t) => t.type.equalsValue(type))).watch();

  SimpleSelectStatement<$CategoriesTable, Category> _ordered() =>
      select(categories)
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
