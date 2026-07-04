import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories.dart';
import '../tables/enums.dart';

part 'category_dao.g.dart';

/// Data access for [Categories].
@DriftAccessor(tables: [Categories])
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

  Future<List<Category>> getAllCategories() => _ordered().get();

  Stream<List<Category>> watchAllCategories() => _ordered().watch();

  Stream<List<Category>> watchByType(CategoryType type) =>
      (_ordered()..where((t) => t.type.equalsValue(type))).watch();

  SimpleSelectStatement<$CategoriesTable, Category> _ordered() =>
      select(categories)
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
