import 'package:drift/drift.dart' show Value;

import '../../database/app_database.dart' as db;
import '../exchange_rate_entry.dart';

/// Mappers between the Drift `ExchangeRates` row and the [ExchangeRateEntry]
/// domain model. `rate` round-trips exactly via the Drift `DecimalConverter`.

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
}
