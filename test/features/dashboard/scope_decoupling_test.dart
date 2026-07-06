import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/services/summary_period_value.dart';

/// PROJECT_PLAN §9 (the two-scope rule): the Summary scope and the List scope
/// are provably independent. Mutating one leaves the other untouched — in BOTH
/// directions.
void main() {
  late db.AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('mutating the Summary account selection does not touch the List filter',
      () {
    // Baseline: List filter is unnarrowed (all wallets).
    expect(container.read(transactionListFilterProvider).walletIds, isEmpty);

    // Mutate ONLY the summary scope.
    container
        .read(summaryAccountSelectionProvider.notifier)
        .setSelection(<int>{1, 2});

    expect(container.read(summaryAccountSelectionProvider), <int>{1, 2});
    // The List filter's wallets are unchanged.
    expect(container.read(transactionListFilterProvider).walletIds, isEmpty);
  });

  test('mutating the List filter does not touch the Summary selection', () {
    // Baseline: summary aggregates over all accounts (empty set).
    expect(container.read(summaryAccountSelectionProvider), isEmpty);

    // Mutate ONLY the list scope.
    container
        .read(transactionListFilterProvider.notifier)
        .setWallets(<int>{3});

    expect(container.read(transactionListFilterProvider).walletIds, <int>{3});
    // The summary selection is unchanged.
    expect(container.read(summaryAccountSelectionProvider), isEmpty);
  });

  test('mutating the Summary period scope updates the List filter range', () {
    // Changing the summary period MUST update the List filter range.
    container.read(summaryPeriodProvider.notifier).setAllTime();
    expect(
      container.read(summaryPeriodProvider).kind,
      SummaryPeriodKind.allTime,
    );
    // Period is now globally shared, so the filter range mirrors it.
    expect(
      container.read(transactionListFilterProvider).range,
      container.read(summaryPeriodProvider).range,
    );

    // But changing other List filter facets (like search) must not disturb the shared period.
    container.read(summaryPeriodProvider.notifier).nextMonth();
    final SummaryPeriodValue before = container.read(summaryPeriodProvider);
    container
        .read(transactionListFilterProvider.notifier)
        .setSearch('anything');
    expect(container.read(summaryPeriodProvider), before);
  });
}
