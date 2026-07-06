import 'package:drift/drift.dart';

import 'enums.dart';

/// An account groups one or more wallets (PROJECT_PLAN §5.2).
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<AccountType>()();
  IntColumn get colorValue => integer()(); // ARGB int
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
