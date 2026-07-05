import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_colors.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/features/dashboard/widgets/summary_card.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Summary Card Refactor §A.8: the pure [SummaryCardBody] renders the 9 cells in
/// tr_TR formatting and colors Row-1/Row-2 signed cells by sign.
void main() {
  const CurrencyService currency = CurrencyService();

  // Deliberately mixed signs and all-distinct magnitudes so each figure maps to
  // a unique formatted string (negative Devreden + negative Bakiye).
  const SummaryData data = SummaryData(
    baseCurrencyCode: 'TRY',
    carriedOverMinor: -5000, // Devreden  (negative → expense accent)
    currentCashMinor: 151500, // Bugünkü Kasa (hero → primary)
    carryForwardMinor: 163500, // Devredecek (positive → income accent)
    incomeTotalMinor: 53500, // Gelir
    expenseTotalMinor: 20000, // Gider
    netBalanceMinor: -8000, // Bakiye    (negative → expense accent)
    collectedIncomeMinor: 33500, // Tahsilat
    receivableIncomeMinor: 21000, // Alacak
    paidExpenseMinor: 12000, // Ödeme
    payableExpenseMinor: 8000, // Borç
  );

  Future<void> pumpBody(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SummaryCardBody(data: data, currency: currency),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('renders all nine figures with tr_TR formatting', (tester) async {
    await pumpBody(tester);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(SummaryCardBody)),
    );

    // Labels.
    for (final String label in <String>[
      l10n.summaryCarriedOver,
      l10n.summaryCurrentCash,
      l10n.summaryCarryForward,
      l10n.summaryIncome,
      l10n.summaryExpense,
      l10n.summaryNet,
      l10n.summaryCollected,
      l10n.summaryReceivable,
      l10n.summaryPaid,
      l10n.summaryPayable,
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Values.
    expect(find.text(currency.format(-5000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(151500, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(163500, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(53500, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(20000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(-8000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(33500, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(21000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(12000, 'TRY')), findsOneWidget);
    expect(find.text(currency.format(8000, 'TRY')), findsOneWidget);
  });

  testWidgets('signed cells flip color by sign; hero uses primary', (
    tester,
  ) async {
    await pumpBody(tester);
    final ThemeData theme = Theme.of(
      tester.element(find.byType(SummaryCardBody)),
    );

    // Negative Devreden and negative Bakiye → expense accent.
    expect(colorOf(tester, currency.format(-5000, 'TRY')),
        AppSemanticColors.dark.expense);
    expect(colorOf(tester, currency.format(-8000, 'TRY')),
        AppSemanticColors.dark.expense);
    // Positive Devredecek → income accent.
    expect(colorOf(tester, currency.format(163500, 'TRY')),
        AppSemanticColors.dark.income);
    // Hero Bugünkü Kasa → primary.
    expect(colorOf(tester, currency.format(151500, 'TRY')),
        theme.colorScheme.primary);
  });
}
