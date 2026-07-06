import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/application/summary_providers.dart';
import '../../transactions/services/summary_data.dart';

/// The dashboard 9-cell Summary card (Summary Card Refactor §A). Watches
/// [summaryProvider] and hands the resolved [SummaryData] to a pure
/// presentational body — leaf cells read no providers, so it repaints cheaply.
///
/// All figures are base-currency, formatted with [CurrencyService.format] under
/// [SummaryData.baseCurrencyCode] (tr_TR grouping, signed). Row-1 balances are
/// running totals; Row-2 are period flows; Row-3 is a single centered line of
/// the four collected/receivable/paid/payable breakdown items that shrinks to
/// fit narrow screens. Dark-theme surfaces only.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SummaryData> summary = ref.watch(summaryProvider);
    final CurrencyService currency = ref.watch(currencyServiceProvider);

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          // Tightened vertical rhythm keeps the card compact (§A.2).
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: summary.when(
            loading: () => const _SummarySkeleton(),
            error: (Object _, StackTrace _) => SizedBox(
              height: _kCardBodyHeight,
              child: Center(
                child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
              ),
            ),
            data: (SummaryData data) =>
                SummaryCardBody(data: data, currency: currency),
          ),
        ),
      ),
    );
  }
}

const double _kCardBodyHeight = 104;

/// Pure, provider-free body rendering the three rows of cells. Exposed
/// (non-private) so widget/golden tests can pump it with a fixed [SummaryData].
class SummaryCardBody extends StatelessWidget {
  const SummaryCardBody({
    super.key,
    required this.data,
    required this.currency,
  });

  final SummaryData data;
  final CurrencyService currency;

  String _fmt(int minor) => currency.format(minor, data.baseCurrencyCode);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Row 1 — running balances (Bugünkü Kasa is the hero).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _BalanceCell(
                label: l10n.summaryCarriedOver,
                value: _fmt(data.carriedOverMinor),
                color: _signColor(data.carriedOverMinor, semantic),
                semantic: semantic,
              ),
            ),
            Expanded(
              child: _BalanceCell(
                label: l10n.summaryCurrentCash,
                value: _fmt(data.currentCashMinor),
                color: theme.colorScheme.primary,
                semantic: semantic,
                hero: true,
              ),
            ),
            Expanded(
              child: _BalanceCell(
                label: l10n.summaryCarryForward,
                value: _fmt(data.carryForwardMinor),
                color: _signColor(data.carryForwardMinor, semantic),
                semantic: semantic,
                alignEnd: true,
              ),
            ),
          ],
        ),
        // A thin hairline replaces the tall Divider to save height (§A.2).
        Divider(
          height: AppSpacing.md,
          thickness: 0.5,
          color: theme.dividerColor.withValues(alpha: 0.4),
        ),
        // Row 2 — period flows.
        Row(
          children: <Widget>[
            Expanded(
              child: _FlowCell(
                label: l10n.summaryIncome,
                value: _fmt(data.incomeTotalMinor),
                color: semantic.income,
                semantic: semantic,
              ),
            ),
            Expanded(
              child: _FlowCell(
                label: l10n.summaryExpense,
                value: _fmt(data.expenseTotalMinor),
                color: semantic.expense,
                semantic: semantic,
              ),
            ),
            Expanded(
              child: _FlowCell(
                label: l10n.summaryNet,
                value: _fmt(data.netBalanceMinor),
                color: _signColor(data.netBalanceMinor, semantic),
                semantic: semantic,
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row 3 — the four breakdown items on ONE centered line that scales
        // down (never wraps/overflows) on narrow screens (§A.2).
        _BreakdownLine(
          semantic: semantic,
          entries: <_BreakdownEntry>[
            _BreakdownEntry(
              l10n.summaryCollected,
              _fmt(data.collectedIncomeMinor),
              semantic.income,
            ),
            _BreakdownEntry(
              l10n.summaryReceivable,
              _fmt(data.receivableIncomeMinor),
              semantic.income,
            ),
            _BreakdownEntry(
              l10n.summaryPaid,
              _fmt(data.paidExpenseMinor),
              semantic.expense,
            ),
            _BreakdownEntry(
              l10n.summaryPayable,
              _fmt(data.payableExpenseMinor),
              semantic.expense,
            ),
          ],
        ),
      ],
    );
  }

  /// Income accent when ≥ 0, expense accent when negative.
  static Color _signColor(int minor, AppSemanticColors s) =>
      minor < 0 ? s.expense : s.income;
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.label,
    required this.value,
    required this.color,
    required this.semantic,
    this.hero = false,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final AppSemanticColors semantic;
  final bool hero;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CrossAxisAlignment cross = hero
        ? CrossAxisAlignment.center
        : (alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start);
    final TextAlign textAlign = hero
        ? TextAlign.center
        : (alignEnd ? TextAlign.end : TextAlign.start);
    final TextStyle? valueStyle = hero
        ? theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          )
        : theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          );

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          textAlign: textAlign,
          style: theme.textTheme.labelSmall?.copyWith(
            color: semantic.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: valueStyle,
        ),
      ],
    );
  }
}

class _FlowCell extends StatelessWidget {
  const _FlowCell({
    required this.label,
    required this.value,
    required this.color,
    required this.semantic,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final AppSemanticColors semantic;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CrossAxisAlignment cross = CrossAxisAlignment.center;
    final TextAlign textAlign = TextAlign.center;
    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          textAlign: textAlign,
          style: theme.textTheme.labelMedium?.copyWith(
            color: semantic.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BreakdownEntry {
  const _BreakdownEntry(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

/// Row 3: all four breakdown items on a single, centered line separated by a
/// muted middot. Wrapped in a scale-down [FittedBox] so it stays on one line and
/// shrinks (never wraps or overflows) on a narrow screen (§A.2).
class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.entries, required this.semantic});

  final List<_BreakdownEntry> entries;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: semantic.textMuted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((_BreakdownEntry e) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                e.label,
                style: labelStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: e.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// A lightweight loading placeholder matching the card body's height so the
/// card does not jump when the first value arrives.
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
