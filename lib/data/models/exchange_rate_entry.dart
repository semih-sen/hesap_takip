import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_rate_entry.freezed.dart';

/// Domain model for a cached exchange-rate observation.
///
/// `rate` is the raw `baseCurrency -> quoteCurrency` multiplier. It is
/// independent of currency minor digits. On create, `id` is assigned by the
/// database and ignored.
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
