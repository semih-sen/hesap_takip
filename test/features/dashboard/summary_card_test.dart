import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_colors.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/features/dashboard/widgets/summary_card.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// PROJECT_PLAN Phase 7, §5: the card renders the three base-currency figures
/// and flips the Net accent with its sign.
void main() {
  const CurrencyService currency = CurrencyService();

  Future<void> pumpCard(WidgetTester tester, SummaryData data) async {
    final db.AppDatabase database = db.AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
    addTearDown(database.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        summaryProvider.overrideWith(
          (Ref ref) => Stream<SummaryData>.value(data),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SummaryCard()),
        ),
      ),
    );
    // Let the overridden stream deliver its value (loading → data).
    await tester.pump();
    await tester.pump();
  }

  Color _colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('renders income, expense and net figures', (tester) async {
    const SummaryData data = SummaryData(incomeMinor: 10000, expenseMinor: 3000);
    await pumpCard(tester, data);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(SummaryCard)),
    );
    expect(find.text(l10n.summaryIncome), findsOneWidget);
    expect(find.text(l10n.summaryExpense), findsOneWidget);
    expect(find.text(l10n.summaryNet), findsOneWidget);

    expect(find.text(currency.format(10000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(3000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(7000, 'TRY')), findsOneWidget); // net
  });

  testWidgets('net uses the income accent when positive', (tester) async {
    const SummaryData data = SummaryData(incomeMinor: 10000, expenseMinor: 3000);
    await pumpCard(tester, data);

    final Color netColor = _colorOf(tester, currency.format(7000, 'TRY'));
    expect(netColor, AppSemanticColors.dark.income);
  });

  testWidgets('net uses the expense accent when negative', (tester) async {
    const SummaryData data = SummaryData(incomeMinor: 1000, expenseMinor: 9000);
    await pumpCard(tester, data);

    // net = -8000
    final Color netColor = _colorOf(tester, currency.format(-8000, 'TRY'));
    expect(netColor, AppSemanticColors.dark.expense);
  });
}
