import 'package:drift/drift.dart' show Value;

import '../../database/app_database.dart' as db;
import '../account.dart';

/// Mappers between the Drift `Accounts` row and the [Account] domain model.
///
/// Mappers are the ONLY place the Drift and domain worlds meet (Phase 2).

extension AccountRowMapper on db.Account {
  Account toDomain() => Account(
    id: id,
    name: name,
    type: type,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isDefault: isDefault,
    isArchived: isArchived,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension AccountDomainMapper on Account {
  /// Full Drift row, used for `update`/`replace` and round-trip verification.
  db.Account toRow() => db.Account(
    id: id,
    name: name,
    type: type,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isDefault: isDefault,
    isArchived: isArchived,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Insert companion for `create`: `id` and audit timestamps are left to the
  /// database (auto-increment / `currentDateAndTime`).
  db.AccountsCompanion toInsertCompanion() => db.AccountsCompanion.insert(
    name: name,
    type: type,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isDefault: Value(isDefault),
    isArchived: Value(isArchived),
    sortOrder: Value(sortOrder),
  );
}
