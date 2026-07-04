import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/app.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/app_database_provider.dart';

void main() {
  testWidgets('boots in dark theme with Turkish navigation and switches tabs', (
    WidgetTester tester,
  ) async {
    // Override the DB with an in-memory instance in case a screen reads it.
    // (The DB-backed accounts screen is covered by accounts_screen_test.dart,
    // which drives Drift's real async via runAsync.)
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const HesapTakipApp(),
      ),
    );
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

    // Dashboard is the initial destination (still a placeholder).
    expect(find.text('Bu bölüm yakında eklenecek.'), findsOneWidget);

    // Navigation switches between placeholder screens (Settings is safe — no DB).
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);
  });
}
