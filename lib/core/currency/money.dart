import 'package:freezed_annotation/freezed_annotation.dart';

part 'money.freezed.dart';

/// Thrown when two [Money] values of different currencies are combined.
///
/// Same-currency arithmetic is exact on integer minor units; mixing currencies
/// is a programming error and must fail loudly rather than produce a wrong sum.
class CurrencyMismatchException implements Exception {
  const CurrencyMismatchException(this.expected, this.actual);

  /// The currency of the left-hand operand.
  final String expected;

  /// The currency of the right-hand operand.
  final String actual;

  @override
  String toString() =>
      'CurrencyMismatchException: cannot combine "$actual" with "$expected"';
}

/// An immutable monetary amount as integer minor units plus its currency.
///
/// PROJECT_PLAN §2: money is never a `double`. All arithmetic here is on
/// [minorUnits] (e.g. cents/kuruş); currency conversion lives in
/// `CurrencyService`, which is the only place a rate is applied.
@freezed
abstract class Money with _$Money {
  const Money._();

  const factory Money({required int minorUnits, required String currencyCode}) =
      _Money;

  /// A zero amount in [currencyCode].
  factory Money.zero(String currencyCode) =>
      Money(minorUnits: 0, currencyCode: currencyCode);

  /// Adds a same-currency amount. Throws [CurrencyMismatchException] otherwise.
  Money operator +(Money other) {
    _assertSameCurrency(other);
    return copyWith(minorUnits: minorUnits + other.minorUnits);
  }

  /// Subtracts a same-currency amount. Throws [CurrencyMismatchException]
  /// otherwise.
  Money operator -(Money other) {
    _assertSameCurrency(other);
    return copyWith(minorUnits: minorUnits - other.minorUnits);
  }

  /// True when this amount is exactly zero.
  bool get isZero => minorUnits == 0;

  /// True when this amount is strictly negative.
  bool get isNegative => minorUnits < 0;

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw CurrencyMismatchException(currencyCode, other.currencyCode);
    }
  }
}
