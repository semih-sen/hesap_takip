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

/// Static registry of known currencies, keyed by upper-case code.
///
/// Seeded with the currencies the app ships with; [register] keeps it extensible
/// (e.g. adding BHD with `minorDigits: 3` later needs no code change here).
abstract final class CurrencyRegistry {
  CurrencyRegistry._();

  static final Map<String, Currency> _currencies = <String, Currency>{
    'TRY': const Currency(
      code: 'TRY',
      symbol: '₺',
      minorDigits: 2,
      symbolOnLeft: false,
    ),
    'USD': const Currency(
      code: 'USD',
      symbol: r'$',
      minorDigits: 2,
      symbolOnLeft: true,
    ),
    'EUR': const Currency(
      code: 'EUR',
      symbol: '€',
      minorDigits: 2,
      symbolOnLeft: true,
    ),
    'GBP': const Currency(
      code: 'GBP',
      symbol: '£',
      minorDigits: 2,
      symbolOnLeft: true,
    ),
    'JPY': const Currency(
      code: 'JPY',
      symbol: '¥',
      minorDigits: 0,
      symbolOnLeft: true,
    ),
  };

  /// Looks up a currency by code (case-insensitive).
  ///
  /// Throws [UnknownCurrencyException] for an unregistered code — money paths
  /// must never fall back to a default.
  static Currency byCode(String code) {
    final Currency? currency = _currencies[code.toUpperCase()];
    if (currency == null) {
      throw UnknownCurrencyException(code);
    }
    return currency;
  }

  /// Whether [code] is registered (case-insensitive).
  static bool isSupported(String code) =>
      _currencies.containsKey(code.toUpperCase());

  /// Registers or replaces a currency, keeping the registry extensible.
  static void register(Currency currency) {
    _currencies[currency.code.toUpperCase()] = currency;
  }

  /// All registered currencies (unspecified order).
  static List<Currency> get all =>
      List<Currency>.unmodifiable(_currencies.values);
}
