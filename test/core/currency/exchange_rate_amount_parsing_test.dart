import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/amount_parsing.dart';

void main() {
  test('exchange rate parser accepts comma or dot decimals', () {
    expect(parseExchangeRateAmount('30,75'), Decimal.parse('30.75'));
    expect(parseExchangeRateAmount('30.75'), Decimal.parse('30.75'));
  });

  test('exchange rate parser treats the last separator as decimal', () {
    expect(parseExchangeRateAmount('1.234,56'), Decimal.parse('1234.56'));
    expect(parseExchangeRateAmount('1,234.56'), Decimal.parse('1234.56'));
  });
}
