import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'currency.dart';

part 'currency_service.g.dart';

/// The money/currency engine (PROJECT_PLAN §6).
///
/// Everything here is deterministic and side-effect free. Rounding is explicit
/// **half-up** (ties away from zero) applied exactly once at each conversion
/// boundary — never chained. All arithmetic stays in [Decimal] until the final
/// integer minor-unit result; no `double` participates in a money path (the
/// `toDouble()` in [format] is a display-only boundary).
class CurrencyService {
  const CurrencyService();

  static final Decimal _half = Decimal.parse('0.5');

  /// Scales [amount] (major units) to integer minor units for [code],
  /// multiplying by `10^minorDigits` and rounding half-up.
  ///
  /// Example: `toMinor(2.005, 'USD') == 201` — the `.5` boundary rounds up.
  int toMinor(Decimal amount, String code) {
    final Currency currency = CurrencyRegistry.byCode(code);
    return _roundHalfUp(amount.shift(currency.minorDigits));
  }

  /// Inverse of [toMinor]: exact major-unit [Decimal] for [minor] units of
  /// [code]. Shifting by a power of ten is exact, so no rounding is involved.
  Decimal fromMinor(int minor, String code) {
    final Currency currency = CurrencyRegistry.byCode(code);
    return Decimal.fromInt(minor).shift(-currency.minorDigits);
  }

  /// Converts [amountMinor] in [fromCode] to integer minor units in [toCode] at
  /// [rate] (major-to-major), rounding half-up exactly once.
  ///
  /// The path is multiplication only (`major * rate`), so it never leaves
  /// [Decimal] for a [Rational]; the single rounding happens in [toMinor].
  int convertMinor({
    required int amountMinor,
    required String fromCode,
    required String toCode,
    required Decimal rate,
  }) {
    final Decimal major = fromMinor(amountMinor, fromCode);
    final Decimal converted = major * rate;
    return toMinor(converted, toCode);
  }

  /// Formats [minor] units of [code] with `tr_TR` grouping by default
  /// (e.g. TRY `1.234,56 ₺`; JPY prints no decimals).
  ///
  /// The symbol and fraction-digit count come from [CurrencyRegistry]; grouping
  /// and symbol placement come from the locale pattern (defaults to `tr_TR`).
  String format(int minor, String code, {Locale? locale}) {
    final Currency currency = CurrencyRegistry.byCode(code);
    final NumberFormat formatter = NumberFormat.currency(
      locale: locale?.toString() ?? 'tr_TR',
      symbol: currency.symbol,
      decimalDigits: currency.minorDigits,
    );
    // Display boundary only: intl needs a `num`. The value handed over is the
    // exact minor-unit amount, so no precision is lost for realistic amounts.
    return formatter.format(fromMinor(minor, code).toDouble());
  }

  /// Rounds a [Decimal] to the nearest integer, ties away from zero (half-up).
  ///
  /// Implemented explicitly (not via [Decimal.round]) so the rounding mode is
  /// guaranteed regardless of the package default.
  int _roundHalfUp(Decimal value) {
    if (value == Decimal.zero) {
      return 0;
    }
    final bool isNegative = value < Decimal.zero;
    final BigInt magnitude = (value.abs() + _half).floor().toBigInt();
    return isNegative ? -magnitude.toInt() : magnitude.toInt();
  }
}

/// App-lifetime singleton [CurrencyService] (stateless; keep-alive).
@Riverpod(keepAlive: true)
CurrencyService currencyService(Ref ref) => const CurrencyService();
