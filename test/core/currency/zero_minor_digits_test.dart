import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/amount_parsing.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';

void main() {
  test(
    '0 minor digit currencies parse, format, and convert with raw rates',
    () {
      final CurrencyService service = CurrencyService(const [
        Currency(code: 'XYZ', symbol: 'X', minorDigits: 0, symbolOnLeft: false),
        Currency(code: 'USD', symbol: r'$', minorDigits: 2, symbolOnLeft: true),
      ]);
      final Decimal parsed = parseTurkishAmount('150')!;

      expect(service.toMinor(parsed, 'XYZ'), 150);
      expect(service.format(150, 'XYZ'), '150X');
      expect(
        service.convertMinor(
          amountMinor: 10000,
          fromCode: 'USD',
          toCode: 'XYZ',
          rate: Decimal.parse('150.5'),
        ),
        15050,
      );
    },
  );
}
