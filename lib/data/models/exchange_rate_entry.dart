import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_rate_entry.freezed.dart';

/// Domain model for a cached exchange-rate observation (PROJECT_PLAN §5.2).
///
/// `rate` is the exact `baseCurrency → quoteCurrency` factor. `asOfDate` is a
/// date-only value. On create, `id` is assigned by the database and ignored.
@freezed
abstract class ExchangeRateEntry with _$ExchangeRateEntry {
  const factory ExchangeRateEntry({
    required int id,
    required String baseCurrency,
    required String quoteCurrency,
    required Decimal rate,
    required DateTime asOfDate,
    String? source,
  }) = _ExchangeRateEntry;
}
