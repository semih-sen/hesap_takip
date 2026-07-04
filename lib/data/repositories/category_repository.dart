import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../database/tables/enums.dart';
import '../models/category.dart';
import '../models/mappers/category_mapper.dart';

part 'category_repository.g.dart';

/// Reactive data API for categories, returning DOMAIN [Category] models.
abstract interface class CategoryRepository {
  /// Categories ordered by `sortOrder`; narrowed to [type] when given.
  Stream<List<Category>> watchCategories({CategoryType? type});

  /// The category with [id], or `null`.
  Future<Category?> findCategory(int id);

  /// Inserts [category] and returns the new row id.
  Future<int> createCategory(Category category);

  /// Replaces the stored category matching [category]'s id.
  Future<void> updateCategory(Category category);

  /// Soft-removes the category by setting `isArchived = true`.
  Future<void> archiveCategory(int id);

  /// Hard-deletes the category (blocked by FK if referenced).
  Future<void> deleteCategory(int id);
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Category>> watchCategories({CategoryType? type}) {
    final Stream<List<db.Category>> rows = type == null
        ? _db.categoryDao.watchAllCategories()
        : _db.categoryDao.watchByType(type);
    return rows.map((list) => list.map((row) => row.toDomain()).toList());
  }

  @override
  Future<Category?> findCategory(int id) async =>
      (await _db.categoryDao.getCategoryById(id))?.toDomain();

  @override
  Future<int> createCategory(Category category) =>
      _db.categoryDao.createCategory(category.toInsertCompanion());

  @override
  Future<void> updateCategory(Category category) =>
      _db.categoryDao.updateCategory(category.toRow());

  @override
  Future<void> archiveCategory(int id) async {
    final db.Category? existing = await _db.categoryDao.getCategoryById(id);
    if (existing == null) {
      return;
    }
    await _db.categoryDao.updateCategory(existing.copyWith(isArchived: true));
  }

  @override
  Future<void> deleteCategory(int id) => _db.categoryDao.deleteCategory(id);
}

/// App-lifetime singleton category repository.
@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    DriftCategoryRepository(ref.watch(appDatabaseProvider));
