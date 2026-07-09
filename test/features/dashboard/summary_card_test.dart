import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_colors.dart';
import 'package:hesap_takip/app/theme/app_spacing.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/features/dashboard/widgets/summary_card.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

void main() {
  const CurrencyService currency = CurrencyService(<Currency>[
    Currency(code: 'TRY', symbol: 'TL', minorDigits: 2, symbolOnLeft: false),
    Currency(code: 'USD', symbol: r'$', minorDigits: 2, symbolOnLeft: true),
    Currency(code: 'EUR', symbol: 'EUR', minorDigits: 2, symbolOnLeft: false),
    Currency(code: 'GBP', symbol: 'GBP', minorDigits: 2, symbolOnLeft: true),
    Currency(code: 'JPY', symbol: 'JPY', minorDigits: 0, symbolOnLeft: true),
  ]);

  const SummaryData data = SummaryData(
    baseCurrencyCode: 'TRY',
    carriedOverMinor: -5000,
    currentCashMinor: 151500,
    carryForwardMinor: 163500,
    incomeTotalMinor: 53500,
    expenseTotalMinor: 20000,
    netBalanceMinor: -8000,
    collectedIncomeMinor: 33500,
    receivableIncomeMinor: 21000,
    paidExpenseMinor: 12000,
    payableExpenseMinor: 8000,
  );

  Future<void> pumpBody(WidgetTester tester, {double width = 360}) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: AppRadius.smAll,
                ),
                clipBehavior: Clip.antiAlias,
                child: const SummaryCardBody(data: data, currency: currency),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('renders all ten labels and figures with tr_TR formatting', (
    tester,
  ) async {
    await pumpBody(tester);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(SummaryCardBody)),
    );

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

    for (final int minor in <int>[
      -5000,
      151500,
      163500,
      53500,
      20000,
      -8000,
      33500,
      21000,
      12000,
      8000,
    ]) {
      expect(find.text(currency.format(minor, 'TRY')), findsOneWidget);
    }
  });

  testWidgets('signed cells flip color by sign; current cash uses income', (
    tester,
  ) async {
    await pumpBody(tester);

    expect(
      colorOf(tester, currency.format(-5000, 'TRY')),
      AppSemanticColors.dark.expense,
    );
    expect(
      colorOf(tester, currency.format(-8000, 'TRY')),
      AppSemanticColors.dark.expense,
    );
    expect(
      colorOf(tester, currency.format(163500, 'TRY')),
      AppSemanticColors.dark.income,
    );
    expect(
      colorOf(tester, currency.format(151500, 'TRY')),
      AppSemanticColors.dark.income,
    );
  });

  testWidgets('renders equivalent values when a display currency is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SummaryCardBody(
            data: data,
            currency: currency,
            equivalentCurrencyCode: 'USD',
            equivalentRate: Decimal.parse('0.03'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(currency.format(4545, 'USD')), findsOneWidget);
    expect(find.text(currency.format(-150, 'USD')), findsOneWidget);
  });

  testWidgets('breakdown row renders all four items without overflow', (
    tester,
  ) async {
    await pumpBody(tester);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(SummaryCardBody)),
    );

    for (final String label in <String>[
      l10n.summaryCollected,
      l10n.summaryReceivable,
      l10n.summaryPaid,
      l10n.summaryPayable,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('default-width layout golden', (tester) async {
    await pumpBody(tester, width: 360);
    await expectLater(
      find.byType(SummaryCardBody),
      matchesGoldenFile('goldens/summary_card_default.png'),
    );
  });

  testWidgets('narrow-width layout golden', (tester) async {
    await pumpBody(tester, width: 320);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SummaryCardBody),
      matchesGoldenFile('goldens/summary_card_narrow.png'),
    );
  });
}
