import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exchange_rates.dart';

part 'exchange_rate_dao.g.dart';

/// Data access for the [ExchangeRates] cache.
@DriftAccessor(tables: [ExchangeRates])
class ExchangeRateDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeRateDaoMixin {
  ExchangeRateDao(super.db);

  Future<int> insertRate(ExchangeRatesCompanion entry) =>
      into(exchangeRates).insert(entry);

  Future<int> deleteRate(int id) =>
      (delete(exchangeRates)..where((t) => t.id.equals(id))).go();

  Stream<List<ExchangeRate>> watchAllRates() =>
      (select(exchangeRates)..orderBy([
            (t) =>
                OrderingTerm(expression: t.asOfDate, mode: OrderingMode.desc),
          ]))
          .watch();

  /// Latest cached rate for a currency pair effective on or before [asOf].
  Future<ExchangeRate?> getLatestRate({
    required String baseCurrency,
    required String quoteCurrency,
    required DateTime asOf,
  }) {
    return (select(exchangeRates)
          ..where(
            (t) =>
                t.baseCurrency.equals(baseCurrency) &
                t.quoteCurrency.equals(quoteCurrency) &
                t.asOfDate.isSmallerOrEqualValue(asOf),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.asOfDate, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }
}
