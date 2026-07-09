import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/features/settings/presentation/exchange_rates_screen.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// §E.6: the exchange-rate CRUD screen lists, adds, and deletes rates.
void main() {
  Future<db.AppDatabase> pump(WidgetTester tester) async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExchangeRatesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return database;
  }

  testWidgets('lists existing rates', (WidgetTester tester) async {
    final database = await pump(tester);
    await tester.runAsync(
      () => database.exchangeRateDao.insertRate(
        db.ExchangeRatesCompanion.insert(
          baseCurrency: 'USD',
          quoteCurrency: 'TRY',
          rate: Decimal.parse('30.5'),
          asOfDate: DateTime(2026, 1, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('USD → TRY'), findsOneWidget);
    expect(find.text('30.5'), findsOneWidget);
  });

  testWidgets('empty state when there are no rates', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );
    expect(find.text(l10n.exchangeRatesEmpty), findsOneWidget);
  });

  testWidgets('deleting a rate removes it after confirmation', (
    WidgetTester tester,
  ) async {
    final database = await pump(tester);
    await tester.runAsync(
      () => database.exchangeRateDao.insertRate(
        db.ExchangeRatesCompanion.insert(
          baseCurrency: 'EUR',
          quoteCurrency: 'TRY',
          rate: Decimal.parse('35.0'),
          asOfDate: DateTime(2026, 1, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EUR → TRY'), findsOneWidget);

    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Confirm dialog → tap "Sil".
    await tester.tap(find.widgetWithText(TextButton, l10n.actionDelete));
    await tester.pumpAndSettle();

    expect(find.text('EUR → TRY'), findsNothing);
    expect(find.text(l10n.exchangeRatesEmpty), findsOneWidget);
  });
}
