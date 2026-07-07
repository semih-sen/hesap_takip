import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/exchange_rate_entry.dart';
import '../models/mappers/exchange_rate_mapper.dart';

part 'exchange_rate_repository.g.dart';

/// Reactive data API for the exchange-rate cache, returning DOMAIN
/// [ExchangeRateEntry] models. Used later to prefill per-transaction rate
/// snapshots (§6); the authoritative rate always lives on the transaction row.
abstract interface class ExchangeRateRepository {
  /// All cached rates, newest `asOfDate` first.
  Stream<List<ExchangeRateEntry>> watchRates();

  /// The newest cached rate for [fromCode] → [toCode] effective on or before
  /// [onOrBefore] (or the newest overall when [onOrBefore] is null). Returns
  /// `null` when no matching rate is cached.
  Future<ExchangeRateEntry?> latestRate(
    String fromCode,
    String toCode, {
    DateTime? onOrBefore,
  });

  /// Inserts [entry] (its `id` is DB-assigned) and returns the new row id.
  Future<int> addRate(ExchangeRateEntry entry);

  /// Deletes the cached rate with [id].
  Future<void> deleteRate(int id);
}

class DriftExchangeRateRepository implements ExchangeRateRepository {
  DriftExchangeRateRepository(this._db);

  final db.AppDatabase _db;

  /// Sentinel used when no upper date bound is supplied: any real `asOfDate`
  /// sorts on or before it, so the DAO returns the newest cached rate.
  static final DateTime _farFuture = DateTime(9999, 12, 31);

  @override
  Stream<List<ExchangeRateEntry>> watchRates() => _db.exchangeRateDao
      .watchAllRates()
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<ExchangeRateEntry?> latestRate(
    String fromCode,
    String toCode, {
    DateTime? onOrBefore,
  }) async {
    final db.ExchangeRate? row = await _db.exchangeRateDao.getLatestRate(
      baseCurrency: fromCode,
      quoteCurrency: toCode,
      asOf: onOrBefore ?? _farFuture,
    );
    return row?.toDomain();
  }

  @override
  Future<int> addRate(ExchangeRateEntry entry) =>
      _db.exchangeRateDao.insertRate(entry.toInsertCompanion());

  @override
  Future<void> deleteRate(int id) => _db.exchangeRateDao.deleteRate(id);
}

/// App-lifetime singleton exchange-rate repository.
@Riverpod(keepAlive: true)
ExchangeRateRepository exchangeRateRepository(Ref ref) =>
    DriftExchangeRateRepository(ref.watch(appDatabaseProvider));

/// Reactive stream of cached rates for application-layer projections.
@riverpod
Stream<List<ExchangeRateEntry>> exchangeRateEntries(Ref ref) =>
    ref.watch(exchangeRateRepositoryProvider).watchRates();
