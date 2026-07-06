import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';

void main() {
  final CurrencyService service = CurrencyService(
    const [
  Currency(code: 'TRY', symbol: '₺', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'USD', symbol: '\$', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'EUR', symbol: '€', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),

],
  );

  group('registry lookup', () {
    test('known codes resolve; JPY has 0 minor digits', () {
      expect(service.byCode('TRY').minorDigits, 2);
      expect(service.byCode('JPY').minorDigits, 0);
      // Case-insensitive.
      expect(service.byCode('usd').code, 'USD');
    });

    test('unknown code throws a typed error', () {
      expect(
        () => service.byCode('XYZ'),
        throwsA(isA<UnknownCurrencyException>()),
      );
    });
  });

  group('toMinor / fromMinor', () {
    test('round-trips a 2-digit currency exactly', () {
      final Decimal amount = Decimal.parse('1234.56');
      final int minor = service.toMinor(amount, 'TRY');
      expect(minor, 123456);
      expect(service.fromMinor(minor, 'TRY'), amount);
    });

    test('round-trips a 0-digit currency exactly', () {
      final Decimal amount = Decimal.parse('123456');
      final int minor = service.toMinor(amount, 'JPY');
      expect(minor, 123456);
      expect(service.fromMinor(minor, 'JPY'), amount);
    });

    test('half-up at the .5 boundary (2-digit): 2.005 -> 201', () {
      expect(service.toMinor(Decimal.parse('2.005'), 'USD'), 201);
      // Just below the boundary rounds down.
      expect(service.toMinor(Decimal.parse('2.0049'), 'USD'), 200);
    });

    test('half-up at the .5 boundary (0-digit): 0.5 -> 1, 2.5 -> 3', () {
      expect(service.toMinor(Decimal.parse('0.5'), 'JPY'), 1);
      expect(service.toMinor(Decimal.parse('1.5'), 'JPY'), 2);
      expect(service.toMinor(Decimal.parse('2.5'), 'JPY'), 3);
    });

    test('negative amounts round half away from zero', () {
      expect(service.toMinor(Decimal.parse('-2.005'), 'USD'), -201);
      expect(service.toMinor(Decimal.parse('-0.5'), 'JPY'), -1);
    });
  });

  group('format (tr_TR)', () {
    test('TRY: Turkish grouping, symbol, 2 decimals', () {
      final String formatted = service.format(123456, 'TRY');
      expect(formatted, contains('1.234,56'));
      expect(formatted, contains('₺'));
    });

    test('USD: Turkish grouping with the dollar symbol', () {
      final String formatted = service.format(123456, 'USD');
      expect(formatted, contains('1.234,56'));
      expect(formatted, contains(r'$'));
    });

    test('JPY: no decimals, Turkish grouping', () {
      final String formatted = service.format(123456, 'JPY');
      expect(formatted, contains('123.456'));
      expect(formatted, contains('¥'));
      // Zero-decimal currency prints no decimal separator.
      expect(formatted.contains(','), isFalse);
    });
  });

  group('convertMinor', () {
    test('cross-currency USD -> TRY (whole-number rate)', () {
      // 100.00 USD at 34.10 = 3410.00 TRY.
      final int result = service.convertMinor(
        amountMinor: 10000,
        fromCode: 'USD',
        toCode: 'TRY',
        rate: Decimal.parse('34.10'),
      );
      expect(result, 341000);
    });

    test('rounds half-up once at the boundary', () {
      // 1.00 USD at 2.005 -> 2.005 TRY -> 200.5 minor -> 201.
      final int result = service.convertMinor(
        amountMinor: 100,
        fromCode: 'USD',
        toCode: 'TRY',
        rate: Decimal.parse('2.005'),
      );
      expect(result, 201);
    });

    test('into a 0-digit currency (USD -> JPY) rounds to whole yen', () {
      // 100.00 USD at 150.567 -> 15056.7 JPY -> 15057 (half-up).
      final int result = service.convertMinor(
        amountMinor: 10000,
        fromCode: 'USD',
        toCode: 'JPY',
        rate: Decimal.parse('150.567'),
      );
      expect(result, 15057);
    });

    test('out of a 0-digit currency (JPY -> USD)', () {
      // 15000 JPY at 0.0066 -> 99.00 USD -> 9900 minor.
      final int result = service.convertMinor(
        amountMinor: 15000,
        fromCode: 'JPY',
        toCode: 'USD',
        rate: Decimal.parse('0.0066'),
      );
      expect(result, 9900);
    });
  });
}
