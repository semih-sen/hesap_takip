import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/features/recurring/presentation/recurring_rule_form_page.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Widget tests for the recurring-rule form (Phase 10): the frequency builder
/// reveals `byMonthDay` vs `byWeekday` per the selected frequency, and the form
/// validates required fields.
void main() {
  Future<db.AppDatabase> pumpForm(WidgetTester tester) async {
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RecurringRuleFormPage(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    return database;
  }

  testWidgets('monthly frequency shows byMonthDay, hides byWeekday', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    // Default frequency is monthly.
    expect(find.byKey(const ValueKey<String>('byMonthDay')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('byWeekday')), findsNothing);
  });

  testWidgets('switching to weekly shows byWeekday, hides byMonthDay', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );

    // Open the frequency dropdown and pick "Haftalık".
    await tester.tap(find.text(l10n.recurringFrequencyMonthly).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurringFrequencyWeekly).last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('byWeekday')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('byMonthDay')), findsNothing);
  });

  testWidgets('switching to daily hides both byMonthDay and byWeekday', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );
    await tester.tap(find.text(l10n.recurringFrequencyMonthly).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurringFrequencyDaily).last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('byMonthDay')), findsNothing);
    expect(find.byKey(const ValueKey<String>('byWeekday')), findsNothing);
  });

  testWidgets('empty required fields block save (no rule persisted)', (
    WidgetTester tester,
  ) async {
    final db.AppDatabase database = await pumpForm(tester);
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('tr'),
    );

    // Tap save with everything empty. The button sits below the fold in a lazy
    // ListView, so drag it into view (building it) first.
    await tester.dragUntilVisible(
      find.text(l10n.actionSave),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    // Validation blocked the save: still on the form, and nothing was written.
    expect(find.byType(RecurringRuleFormPage), findsOneWidget);
    final rules = await database.recurringDao.getActiveRules();
    expect(rules, isEmpty);
  });
}
