import 'package:drift/drift.dart';

import 'enums.dart';

/// Hierarchical income/expense categories (PROJECT_PLAN §5.2).
///
/// `parentId` is a nullable self-reference enabling parent/child hierarchies.
/// The data class is named `Category` (Drift's default de-pluralization would
/// produce the ungrammatical `Categorie`).
@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<CategoryType>()();
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
