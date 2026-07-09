import 'package:drift/drift.dart' show Value;

import '../../database/app_database.dart' as db;
import '../exchange_rate_entry.dart';

/// Mappers between the Drift `ExchangeRates` row and the [ExchangeRateEntry]
/// domain model. `rate` round-trips as an exact Decimal text value.

extension ExchangeRateRowMapper on db.ExchangeRate {
  ExchangeRateEntry toDomain() => ExchangeRateEntry(
    id: id,
    baseCurrency: baseCurrency,
    quoteCurrency: quoteCurrency,
    rate: rate,
    asOfDate: asOfDate,
    source: source,
  );
}

extension ExchangeRateDomainMapper on ExchangeRateEntry {
  db.ExchangeRate toRow() => db.ExchangeRate(
    id: id,
    baseCurrency: baseCurrency,
    quoteCurrency: quoteCurrency,
    rate: rate,
    asOfDate: asOfDate,
    source: source,
  );

  /// Insert companion for `create`: `id` is assigned by the database.
  db.ExchangeRatesCompanion toInsertCompanion() =>
      db.ExchangeRatesCompanion.insert(
        baseCurrency: baseCurrency,
        quoteCurrency: quoteCurrency,
        rate: rate,
        asOfDate: asOfDate,
        source: Value(source),
      );

  db.ExchangeRatesCompanion toUpdateCompanion() => db.ExchangeRatesCompanion(
    id: Value(id),
    baseCurrency: Value(baseCurrency),
    quoteCurrency: Value(quoteCurrency),
    rate: Value(rate),
    asOfDate: Value(asOfDate),
    source: Value(source),
  );
}
