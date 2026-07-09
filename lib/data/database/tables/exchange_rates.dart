import 'package:drift/drift.dart';

import '../converters/decimal_converter.dart';

/// Exchange-rate cache (PROJECT_PLAN section 5.2).
///
/// A helper used to prefill the rate on new transactions; the authoritative
/// snapshot always lives on the transaction row itself. `rate` is stored exactly
/// as Decimal text, independent of currency minor digits.
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get baseCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get quoteCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get rate => text().map(const DecimalConverter())();
  DateTimeColumn get asOfDate => dateTime()(); // date-only
  TextColumn get source => text().nullable()();
}
