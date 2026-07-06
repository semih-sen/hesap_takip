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

    // Own the container and dispose it in addTearDown (after the pending-timer
    // check) so the dashboard's live Drift list stream — kept alive by the
    // IndexedStack shell — tears down cleanly. Drive the stream with runAsync so
    // it emits its first (empty) value before we settle. See the Phase-3
    // drift-stream-in-widget-test gotcha.
    final ProviderContainer container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HesapTakipApp(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
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

    // Dashboard is the initial destination — the real transaction-list host
    // (Phase 5), identified by its add-transaction FAB.
    expect(find.text('İşlem ekle'), findsOneWidget);

    // Navigation switches between screens. The real Settings screen (Phase 11)
    // shows the base-currency row.
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana para birimi'), findsWidgets);
  });
}
