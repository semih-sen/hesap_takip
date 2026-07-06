import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/date/date_range.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/transactions_providers.dart';
import '../../services/summary_period_value.dart';

/// The preset options reachable from the period menu.
enum _PeriodPreset { last30Days, allTime, custom }

/// Period control for the LIST scope (§C.3) — a near-mirror of
/// `SummaryPeriodSwitcher`, but wired to [TransactionListPeriod] so it is fully
/// independent of the Summary scope (the two-scope rule, §9). Shows the current
/// month as "Ay Yıl" with prev/next arrows and a menu (Son 30 gün / Tüm zamanlar
/// / Özel). Reuses the scope-agnostic `summaryPeriod*` ARB strings.
class TransactionListPeriodSwitcher extends ConsumerWidget {
  const TransactionListPeriodSwitcher({super.key});

  static final DateFormat _monthFormat = DateFormat.yMMMM('tr_TR');
  static final DateFormat _dayFormat = DateFormat.yMd('tr_TR');

  String _label(AppLocalizations l10n, SummaryPeriodValue period) {
    switch (period.kind) {
      case SummaryPeriodKind.month:
        return _monthFormat.format(period.anchor!);
      case SummaryPeriodKind.last30Days:
        return l10n.summaryPeriodLast30Days;
      case SummaryPeriodKind.allTime:
        return l10n.summaryPeriodAllTime;
      case SummaryPeriodKind.custom:
        final DateRange r = period.customRange!;
        return '${_dayFormat.format(r.start)} – ${_dayFormat.format(r.end)}';
    }
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    SummaryPeriodValue current,
  ) async {
    final DateRange currentRange = current.range;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      locale: const Locale('tr'),
      initialDateRange: DateTimeRange(
        start: currentRange.start,
        end: currentRange.end,
      ),
    );
    if (picked == null) {
      return;
    }
    ref.read(transactionListPeriodProvider.notifier).setCustomRange(
          DateRange(start: picked.start, end: picked.end),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SummaryPeriodValue period = ref.watch(transactionListPeriodProvider);
    final TransactionListPeriod notifier = ref.read(
      transactionListPeriodProvider.notifier,
    );

    return Row(
      children: <Widget>[
        IconButton(
          tooltip: l10n.summaryPeriodPrevious,
          onPressed: notifier.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: PopupMenuButton<_PeriodPreset>(
            position: PopupMenuPosition.under,
            onSelected: (_PeriodPreset preset) {
              switch (preset) {
                case _PeriodPreset.last30Days:
                  notifier.setLast30Days();
                case _PeriodPreset.allTime:
                  notifier.setAllTime();
                case _PeriodPreset.custom:
                  _pickCustomRange(context, ref, period);
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_PeriodPreset>>[
                  PopupMenuItem<_PeriodPreset>(
                    value: _PeriodPreset.last30Days,
                    child: Text(l10n.summaryPeriodLast30Days),
                  ),
                  PopupMenuItem<_PeriodPreset>(
                    value: _PeriodPreset.allTime,
                    child: Text(l10n.summaryPeriodAllTime),
                  ),
                  PopupMenuItem<_PeriodPreset>(
                    value: _PeriodPreset.custom,
                    child: Text(l10n.summaryPeriodCustom),
                  ),
                ],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    _label(l10n, period),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.summaryPeriodNext,
          onPressed: notifier.nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// A small caption shown only when overdue pending items dated BEFORE the
/// current period are actually being carried into the visible list (§C.5).
/// Computed client-side from the already-loaded rows — no extra query.
class TransactionListOverdueNotice extends ConsumerWidget {
  const TransactionListOverdueNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SummaryPeriodValue period = ref.watch(transactionListPeriodProvider);
    final DateTime start = period.range.start;
    final bool anyCarried = ref
        .watch(visibleTransactionsProvider)
        .any((TransactionListRow r) => r.valueDate.isBefore(start));
    if (!anyCarried) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 14,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              l10n.listOverdueCarriedNotice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
