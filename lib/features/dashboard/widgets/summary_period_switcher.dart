import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/date/date_range.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/application/summary_providers.dart';
import '../../transactions/services/summary_period_value.dart';

/// The preset options reachable from the period menu.
enum _PeriodPreset { last30Days, allTime, custom }

/// Period control for the Summary scope (PROJECT_PLAN Phase 7, D3): the current
/// period is shown as "Ay Yıl" (e.g. *Temmuz 2026*) with left/right arrows for
/// endless month navigation, and a menu offering Son 30 gün / Tüm zamanlar /
/// Özel (a Material date-range picker). Every action updates ONLY
/// [SummaryPeriod]; the List scope is never touched.
class SummaryPeriodSwitcher extends ConsumerWidget {
  const SummaryPeriodSwitcher({super.key});

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
    ref.read(summaryPeriodProvider.notifier).setCustomRange(
          DateRange(start: picked.start, end: picked.end),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SummaryPeriodValue period = ref.watch(summaryPeriodProvider);
    final SummaryPeriod notifier = ref.read(summaryPeriodProvider.notifier);

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
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_PeriodPreset>>[
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
