/// Currency metadata and a static, extensible registry (PROJECT_PLAN §6).
library;

/// Thrown when a currency code is not present in [CurrencyRegistry].
///
/// A typed error (rather than a null return) so callers cannot silently proceed
/// with an unknown currency in a money path.
class UnknownCurrencyException implements Exception {
  const UnknownCurrencyException(this.code);

  /// The offending, unregistered code as supplied by the caller.
  final String code;

  @override
  String toString() =>
      'UnknownCurrencyException: no currency registered for code "$code"';
}

/// Immutable metadata describing a currency.
///
/// `minorDigits` drives every rounding/formatting decision (TRY/USD/EUR/GBP = 2,
/// JPY = 0). `symbolOnLeft` records the conventional symbol placement; the
/// formatter in `CurrencyService` relies on the `tr_TR` locale pattern for
/// grouping and placement, but the field is kept for future locale-agnostic
/// rendering.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.minorDigits,
    required this.symbolOnLeft,
  });

  /// ISO 4217 alphabetic code, upper-case (e.g. `TRY`).
  final String code;

  /// Display symbol (e.g. `₺`).
  final String symbol;

  /// Number of fractional digits the currency subdivides into.
  final int minorDigits;

  /// Whether the symbol conventionally precedes the amount.
  final bool symbolOnLeft;

  @override
  bool operator ==(Object other) =>
      other is Currency &&
      other.code == code &&
      other.symbol == symbol &&
      other.minorDigits == minorDigits &&
      other.symbolOnLeft == symbolOnLeft;

  @override
  int get hashCode => Object.hash(code, symbol, minorDigits, symbolOnLeft);

  @override
  String toString() => 'Currency($code, minorDigits: $minorDigits)';
}


