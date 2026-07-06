import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/date/app_date.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/presentation/widgets/transaction_list_period_switcher.dart';
import 'package:hesap_takip/features/transactions/services/summary_period_value.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// §C.6: the List period switcher drives ONLY the List period; the Summary
/// scope is untouched.
void main() {
  testWidgets('next-month button advances the List period, not the Summary', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SummaryPeriodValue summaryBefore = container.read(
      summaryPeriodProvider,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TransactionListPeriodSwitcher()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final DateTime today = AppDate.today();
    // Tap the next-month chevron.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    // The List period advanced one month...
    expect(
      container.read(transactionListPeriodProvider).range.start,
      DateTime(today.year, today.month + 1, 1),
    );
    // ...and the Summary period is unchanged.
    expect(container.read(summaryPeriodProvider), summaryBefore);
  });

  testWidgets('the All-time menu option switches the List period', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TransactionListPeriodSwitcher()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );
    // Open the period menu and choose "Tüm zamanlar".
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.summaryPeriodAllTime).last);
    await tester.pumpAndSettle();

    expect(
      container.read(transactionListPeriodProvider).kind,
      SummaryPeriodKind.allTime,
    );
  });
}
