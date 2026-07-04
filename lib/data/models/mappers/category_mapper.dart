import 'package:drift/drift.dart' show Value;

import '../../database/app_database.dart' as db;
import '../category.dart';

/// Mappers between the Drift `Categories` row and the [Category] domain model.

extension CategoryRowMapper on db.Category {
  Category toDomain() => Category(
    id: id,
    name: name,
    type: type,
    parentId: parentId,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: isArchived,
    sortOrder: sortOrder,
  );
}

extension CategoryDomainMapper on Category {
  db.Category toRow() => db.Category(
    id: id,
    name: name,
    type: type,
    parentId: parentId,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: isArchived,
    sortOrder: sortOrder,
  );

  db.CategoriesCompanion toInsertCompanion() => db.CategoriesCompanion.insert(
    name: name,
    type: type,
    parentId: Value(parentId),
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: Value(isArchived),
    sortOrder: Value(sortOrder),
  );
}
