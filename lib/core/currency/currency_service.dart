import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/seed.dart';
import '../../data/repositories/currency_repository.dart';
import 'currency.dart';

part 'currency_service.g.dart';

/// The money/currency engine.
///
/// Rounding is explicit half-up (ties away from zero) and applied exactly once
/// at each conversion boundary. Monetary parsing/formatting uses [Decimal],
/// while exchange-rate conversion intentionally applies the raw `double`
/// multiplier without compensating for either currency's minor digits.
class CurrencyService {
  const CurrencyService(this._currencies);

  final List<Currency> _currencies;

  static final Decimal _half = Decimal.parse('0.5');

  /// Looks up a currency by code (case-insensitive).
  /// Throws [UnknownCurrencyException] for an unregistered code.
  Currency byCode(String code) {
    final String upper = code.toUpperCase();
    for (final Currency c in _currencies) {
      if (c.code.toUpperCase() == upper) {
        return c;
      }
    }
    throw UnknownCurrencyException(code);
  }

  /// Whether [code] is registered (case-insensitive).
  bool isSupported(String code) {
    final String upper = code.toUpperCase();
    return _currencies.any((Currency c) => c.code.toUpperCase() == upper);
  }

  /// All known currencies.
  List<Currency> get all => List<Currency>.unmodifiable(_currencies);

  /// Scales [amount] (major units) to integer minor units for [code],
  /// multiplying by `10^minorDigits` and rounding half-up.
  int toMinor(Decimal amount, String code) {
    final Currency currency = byCode(code);
    return _roundHalfUp(amount.shift(currency.minorDigits));
  }

  /// Inverse of [toMinor]: exact major-unit [Decimal] for [minor] units of
  /// [code]. Shifting by a power of ten is exact, so no rounding is involved.
  Decimal fromMinor(int minor, String code) {
    final Currency currency = byCode(code);
    return Decimal.fromInt(minor).shift(-currency.minorDigits);
  }

  /// Converts [amountMinor] in [fromCode] to integer minor units in [toCode] at
  /// [rate] (major-to-major), rounding half-up exactly once.
  int convertMinor({
    required int amountMinor,
    required String fromCode,
    required String toCode,
    required double rate,
  }) {
    final Decimal major = fromMinor(amountMinor, fromCode);
    final Decimal converted = Decimal.parse(
      (major.toDouble() * rate).toString(),
    );
    return toMinor(converted, toCode);
  }

  /// Formats [minor] units of [code] with locale-aware grouping.
  ///
  /// Symbol placement respects [Currency.symbolOnLeft] rather than the
  /// locale's default currency pattern.
  String format(int minor, String code, {Locale? locale}) {
    final Currency currency = byCode(code);
    final String localeStr = locale?.toString() ?? 'tr_TR';
    final NumberFormat formatter = NumberFormat.decimalPatternDigits(
      locale: localeStr,
      decimalDigits: currency.minorDigits,
    );
    final String number = formatter.format(fromMinor(minor, code).toDouble());
    return currency.symbolOnLeft
        ? '${currency.symbol}$number'
        : '$number${currency.symbol}';
  }

  int _roundHalfUp(Decimal value) {
    if (value == Decimal.zero) {
      return 0;
    }
    final bool isNegative = value < Decimal.zero;
    final BigInt magnitude = (value.abs() + _half).floor().toBigInt();
    return isNegative ? -magnitude.toInt() : magnitude.toInt();
  }
}

@Riverpod(keepAlive: true)
Stream<List<Currency>> currencies(Ref ref) {
  return ref.watch(currencyRepositoryProvider).watchAllCurrencies();
}

/// App-lifetime singleton [CurrencyService]. It is injected synchronously using
/// the latest available currencies from the DB, falling back to defaults if
/// still loading, preventing UI flashes.
@Riverpod(keepAlive: true)
CurrencyService currencyService(Ref ref) {
  final AsyncValue<List<Currency>> asyncCurrencies =
      ref.watch(currenciesProvider);

  final List<Currency> currencies = asyncCurrencies.asData?.value ??
      kDefaultCurrencies
          .map(
            (SeedCurrency c) => Currency(
              code: c.code,
              symbol: c.symbol,
              minorDigits: c.minorDigits,
              symbolOnLeft: c.symbolOnLeft,
            ),
          )
          .toList();

  return CurrencyService(currencies);
}
