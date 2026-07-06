import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/date/app_date.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/services/summary_period_value.dart';

/// §C.3/§C.6: the List has its own period scope, independent of the Summary
/// scope, defaulting to the current month and pushing its range into the List
/// filter.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  TransactionListPeriod notifier() =>
      container.read(transactionListPeriodProvider.notifier);

  test('defaults to the current month', () {
    final SummaryPeriodValue period = container.read(
      transactionListPeriodProvider,
    );
    expect(period.kind, SummaryPeriodKind.month);
    final DateTime today = AppDate.today();
    expect(period.range.start, DateTime(today.year, today.month, 1));
    expect(period.range.end, DateTime(today.year, today.month + 1, 0));
  });

  test('nextMonth / previousMonth navigate calendar months', () {
    final DateTime today = AppDate.today();
    notifier().nextMonth();
    expect(
      container.read(transactionListPeriodProvider).range.start,
      DateTime(today.year, today.month + 1, 1),
    );
    notifier().previousMonth();
    notifier().previousMonth();
    expect(
      container.read(transactionListPeriodProvider).range.start,
      DateTime(today.year, today.month - 1, 1),
    );
  });

  test('changing the period pushes its range into the List filter', () {
    // Baseline: filter has no range until the period is touched.
    expect(container.read(transactionListFilterProvider).range, isNull);

    notifier().setAllTime();
    final DateRange? pushed = container
        .read(transactionListFilterProvider)
        .range;
    expect(pushed, isNotNull);
    expect(pushed, container.read(transactionListPeriodProvider).range);

    notifier().nextMonth();
    expect(
      container.read(transactionListFilterProvider).range,
      container.read(transactionListPeriodProvider).range,
    );
  });

  test('two-scope rule: the List period never touches the Summary scope', () {
    notifier().setAllTime();
    notifier().nextMonth();
    // Summary period and account selection are untouched.
    expect(
      container.read(summaryPeriodProvider).kind,
      SummaryPeriodKind.month,
    );
    expect(container.read(summaryAccountSelectionProvider), isEmpty);
  });

  test('two-scope rule: the Summary period never touches the List period', () {
    final SummaryPeriodValue before = container.read(
      transactionListPeriodProvider,
    );
    container.read(summaryPeriodProvider.notifier).setAllTime();
    container.read(summaryPeriodProvider.notifier).nextMonth();
    expect(container.read(transactionListPeriodProvider), before);
  });
}
