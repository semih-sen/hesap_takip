import 'package:drift/drift.dart';

/// Singleton settings row (PROJECT_PLAN §5.2). Always exactly one row with
/// `id = 1`, seeded on database creation. Data class is `AppSetting`.
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get baseCurrencyCode =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('TRY'))();
  IntColumn get firstDayOfWeek =>
      integer().withDefault(const Constant(1))(); // Mon

  @override
  Set<Column> get primaryKey => {id};
}
