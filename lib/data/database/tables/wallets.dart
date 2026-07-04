import 'package:drift/drift.dart';

import 'accounts.dart';

/// A wallet belongs to one account and has its own currency and balance
/// (PROJECT_PLAN §5.2).
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3)(); // ISO 4217
  IntColumn get initialBalanceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
