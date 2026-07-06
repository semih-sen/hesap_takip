
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';

void main() {
  test('test 0 minor digits formatting', () {
    final CurrencyService service = CurrencyService(const [
      Currency(code: 'XYZ', symbol: 'X', minorDigits: 0, symbolOnLeft: false),
    ]);
    print(service.format(150, 'XYZ'));
  });
}
