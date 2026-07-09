import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/date/date_range.dart';
import '../../../data/models/exchange_rate_entry.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/application/summary_providers.dart';
import '../../transactions/services/summary_data.dart';
import '../../transactions/services/summary_period_value.dart';

enum _PeriodPreset { last30Days, allTime, custom }

/// Dashboard summary card with an integrated period header and finance grid.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  static final DateFormat _monthFormat = DateFormat.yMMMM('tr_TR');
  static final DateFormat _dayFormat = DateFormat.yMd('tr_TR');

  String _periodLabel(AppLocalizations l10n, SummaryPeriodValue period) {
    switch (period.kind) {
      case SummaryPeriodKind.month:
        return _monthFormat.format(period.anchor!);
      case SummaryPeriodKind.last30Days:
        return l10n.summaryPeriodLast30Days;
      case SummaryPeriodKind.allTime:
        return l10n.summaryPeriodAllTime;
      case SummaryPeriodKind.custom:
        final DateRange r = period.customRange!;
        return '${_dayFormat.format(r.start)} - ${_dayFormat.format(r.end)}';
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
    ref
        .read(summaryPeriodProvider.notifier)
        .setCustomRange(DateRange(start: picked.start, end: picked.end));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SummaryData> summary = ref.watch(summaryProvider);
    final CurrencyService currency = ref.watch(currencyServiceProvider);
    final SummaryPeriodValue period = ref.watch(summaryPeriodProvider);
    final String primaryCurrency = ref.watch(primaryCurrencyProvider);
    final List<ExchangeRateEntry> rates =
        ref.watch(exchangeRateEntriesProvider).value ??
        const <ExchangeRateEntry>[];
    final SummaryPeriod periodNotifier = ref.read(
      summaryPeriodProvider.notifier,
    );
    final Decimal? equivalentRate = _equivalentRate(
      rates,
      fromCode: summary.asData?.value.baseCurrencyCode,
      toCode: primaryCurrency,
      onOrBefore: period.range.end,
    );

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PeriodHeader(
            label: _periodLabel(l10n, period),
            previousTooltip: l10n.summaryPeriodPrevious,
            nextTooltip: l10n.summaryPeriodNext,
            onPrevious: periodNotifier.previousMonth,
            onNext: periodNotifier.nextMonth,
            onPresetSelected: (_PeriodPreset preset) {
              switch (preset) {
                case _PeriodPreset.last30Days:
                  periodNotifier.setLast30Days();
                case _PeriodPreset.allTime:
                  periodNotifier.setAllTime();
                case _PeriodPreset.custom:
                  _pickCustomRange(context, ref, period);
              }
            },
            menuItems: <PopupMenuEntry<_PeriodPreset>>[
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
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              border: Border.all(color: AppColors.outline),
              borderRadius: AppRadius.smAll,
            ),
            clipBehavior: Clip.antiAlias,
            child: summary.when(
              loading: () => const _SummarySkeleton(),
              error: (Object _, StackTrace _) => SizedBox(
                height: _kCardBodyHeight,
                child: Center(
                  child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
                ),
              ),
              data: (SummaryData data) => SummaryCardBody(
                data: data,
                currency: currency,
                equivalentCurrencyCode:
                    data.baseCurrencyCode == primaryCurrency ||
                        !currency.isSupported(primaryCurrency) ||
                        equivalentRate == null
                    ? null
                    : primaryCurrency,
                equivalentRate: equivalentRate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Decimal? _equivalentRate(
    List<ExchangeRateEntry> rates, {
    required String? fromCode,
    required String toCode,
    required DateTime onOrBefore,
  }) {
    if (fromCode == null || fromCode == toCode) {
      return null;
    }
    final Decimal? direct = _latestRate(rates, fromCode, toCode, onOrBefore);
    if (direct != null) {
      return direct;
    }
    final Decimal? inverse = _latestRate(rates, toCode, fromCode, onOrBefore);
    if (inverse != null && inverse != Decimal.zero) {
      return _reciprocal(inverse);
    }
    return null;
  }

  Decimal? _latestRate(
    List<ExchangeRateEntry> rates,
    String fromCode,
    String toCode,
    DateTime onOrBefore,
  ) {
    ExchangeRateEntry? best;
    for (final ExchangeRateEntry rate in rates) {
      if (rate.baseCurrency != fromCode ||
          rate.quoteCurrency != toCode ||
          rate.asOfDate.isAfter(onOrBefore)) {
        continue;
      }
      if (best == null || rate.asOfDate.isAfter(best.asOfDate)) {
        best = rate;
      }
    }
    return best?.rate;
  }

  Decimal _reciprocal(Decimal value) =>
      (Decimal.one / value).toDecimal(scaleOnInfinitePrecision: 12);
}

const double _kCardBodyHeight = 148;

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.label,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.onPrevious,
    required this.onNext,
    required this.onPresetSelected,
    required this.menuItems,
  });

  final String label;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final PopupMenuItemSelected<_PeriodPreset> onPresetSelected;
  final List<PopupMenuEntry<_PeriodPreset>> menuItems;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.75),
        ),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: <Widget>[
          _HeaderArrowButton(
            tooltip: previousTooltip,
            icon: Icons.chevron_left,
            onPressed: onPrevious,
          ),
          Expanded(
            child: PopupMenuButton<_PeriodPreset>(
              position: PopupMenuPosition.under,
              onSelected: onPresetSelected,
              itemBuilder: (BuildContext context) => menuItems,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          _HeaderArrowButton(
            tooltip: nextTooltip,
            icon: Icons.chevron_right,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _HeaderArrowButton extends StatelessWidget {
  const _HeaderArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(
              color: AppColors.textPrimary.withValues(alpha: 0.85),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

class SummaryCardBody extends StatelessWidget {
  const SummaryCardBody({
    super.key,
    required this.data,
    required this.currency,
    this.equivalentCurrencyCode,
    this.equivalentRate,
  });

  final SummaryData data;
  final CurrencyService currency;
  final String? equivalentCurrencyCode;
  final Decimal? equivalentRate;

  String _fmt(int minor) => currency.format(minor, data.baseCurrencyCode);
  String? _equivalent(int minor) {
    final String? code = equivalentCurrencyCode;
    final Decimal? rate = equivalentRate;
    if (code == null || rate == null) {
      return null;
    }
    final int converted = currency.convertMinor(
      amountMinor: minor,
      fromCode: data.baseCurrencyCode,
      toCode: code,
      rate: rate,
    );
    return currency.format(converted, code);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryCarriedOver,
                  value: _fmt(data.carriedOverMinor),
                  equivalentValue: _equivalent(data.carriedOverMinor),
                  color: _signColor(data.carriedOverMinor, semantic),
                  compact: true,
                ),
              ),
              _VerticalRule(height: 30, color: theme.dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryCurrentCash,
                  value: _fmt(data.currentCashMinor),
                  equivalentValue: _equivalent(data.currentCashMinor),
                  color: semantic.income,
                  compact: true,
                ),
              ),
              _VerticalRule(height: 30, color: theme.dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryCarryForward,
                  value: _fmt(data.carryForwardMinor),
                  equivalentValue: _equivalent(data.carryForwardMinor),
                  color: _signColor(data.carryForwardMinor, semantic),
                  compact: true,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.outline),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryIncome,
                  value: _fmt(data.incomeTotalMinor),
                  equivalentValue: _equivalent(data.incomeTotalMinor),
                  color: semantic.income,
                ),
              ),
              _VerticalRule(height: 44, color: theme.dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryExpense,
                  value: _fmt(data.expenseTotalMinor),
                  equivalentValue: _equivalent(data.expenseTotalMinor),
                  color: semantic.expense,
                ),
              ),
              _VerticalRule(height: 44, color: theme.dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryNet,
                  value: _fmt(data.netBalanceMinor),
                  equivalentValue: _equivalent(data.netBalanceMinor),
                  color: _signColor(data.netBalanceMinor, semantic),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Divider(height: 1, thickness: 1, color: AppColors.outline),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryCollected,
                  value: _fmt(data.collectedIncomeMinor),
                  equivalentValue: _equivalent(data.collectedIncomeMinor),
                  color: semantic.income,
                  smallValue: true,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryReceivable,
                  value: _fmt(data.receivableIncomeMinor),
                  equivalentValue: _equivalent(data.receivableIncomeMinor),
                  color: Colors.amber,
                  smallValue: true,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryPaid,
                  value: _fmt(data.paidExpenseMinor),
                  equivalentValue: _equivalent(data.paidExpenseMinor),
                  color: semantic.expense,
                  smallValue: true,
                ),
              ),
              Expanded(
                child: _SummaryCell(
                  label: l10n.summaryPayable,
                  value: _fmt(data.payableExpenseMinor),
                  equivalentValue: _equivalent(data.payableExpenseMinor),
                  color: semantic.expense,
                  smallValue: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _signColor(int minor, AppSemanticColors semantic) =>
      minor < 0 ? semantic.expense : semantic.income;
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
    this.equivalentValue,
    this.compact = false,
    this.smallValue = false,
  });

  final String label;
  final String value;
  final Color color;
  final String? equivalentValue;
  final bool compact;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final TextStyle? valueStyle =
        (smallValue ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: smallValue ? 14 : 16,
              height: 1,
            );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          style: theme.textTheme.labelSmall?.copyWith(
            color: semantic.textMuted,
            height: 1,
          ),
        ),
        SizedBox(height: compact ? 2 : 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, maxLines: 1, style: valueStyle),
        ),
        if (equivalentValue != null) ...<Widget>[
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              equivalentValue!,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: color.withValues(alpha: 0.55),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _kCardBodyHeight,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
