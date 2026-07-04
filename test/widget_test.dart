import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/app.dart';

void main() {
  testWidgets('boots in dark theme with Turkish navigation and switches tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HesapTakipApp()));
    await tester.pumpAndSettle();

    // Dark theme only (PROJECT_PLAN §10.1).
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme, isNull);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    // Turkish locale + localized bottom navigation labels.
    expect(app.supportedLocales, contains(const Locale('tr')));
    expect(find.text('Panel'), findsWidgets);
    expect(find.text('Hesaplar'), findsOneWidget);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);

    // Dashboard is the initial destination.
    expect(find.text('Bu bölüm yakında eklenecek.'), findsOneWidget);

    // Navigation switches between placeholder screens.
    await tester.tap(find.text('Hesaplar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);
  });
}
