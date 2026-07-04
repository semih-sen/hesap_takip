import 'package:drift/drift.dart';

import 'categories.dart';
import 'enums.dart';
import 'wallets.dart';

/// A rule that generates recurring transactions (PROJECT_PLAN §5.2).
///
/// Date columns (`startDate`, `endDate`, `lastGeneratedDate`) are date-only
/// concepts; they are stored as text via the database-wide
/// `store_date_time_values_as_text` option and normalized to local midnight by
/// the recurring service in a later phase.
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get type => intEnum<TransactionType>()();
  IntColumn get flowDirection => intEnum<FlowDirection>()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  IntColumn get frequency => intEnum<RecurrenceFrequency>()();
  IntColumn get interval =>
      integer().withDefault(const Constant(1))(); // every N units
  IntColumn get byMonthDay => integer().nullable()(); // 1..31 (clamped)
  IntColumn get byWeekday => integer().nullable()(); // 1..7

  DateTimeColumn get startDate => dateTime()(); // date-only
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get maxOccurrences => integer().nullable()();
  IntColumn get generatedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastGeneratedDate => dateTime().nullable()();

  BoolColumn get autoPost =>
      boolean().withDefault(const Constant(false))(); // completed vs pending
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Recurring rule ↔ Category many-to-many (PROJECT_PLAN §5.2). Deleting a rule
/// cascades to its category links.
@DataClassName('RecurringRuleCategory')
class RecurringRuleCategories extends Table {
  IntColumn get ruleId =>
      integer().references(RecurringRules, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  @override
  Set<Column> get primaryKey => {ruleId, categoryId};
}
