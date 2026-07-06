import 'package:drift/drift.dart';

/// User-managed currencies (PROJECT_PLAN §5.2).
///
/// Replaces the static CurrencyRegistry. Stores currency codes, symbols,
/// decimal precision, and formatting preferences.
@DataClassName('CurrencyData')
class Currencies extends Table {
  TextColumn get code => text().withLength(min: 3, max: 3)();
  TextColumn get symbol => text()();
  IntColumn get minorDigits => integer()();
  BoolColumn get symbolOnLeft => boolean()();

  @override
  Set<Column> get primaryKey => {code};
}
