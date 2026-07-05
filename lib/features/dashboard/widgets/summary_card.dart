import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/application/summary_providers.dart';
import '../../transactions/services/summary_data.dart';

/// The dashboard Summary card (PROJECT_PLAN §8.3 / Phase 7): base-currency
/// income / expense / net for the selected period + account scope. Watches
/// [summaryProvider] only — it is fully decoupled from the List scope.
///
/// Every figure is formatted with [CurrencyService.format] under the CURRENT
/// base currency code. Historical rows were snapshotted in `base_amount_minor`
/// under whatever base was active then; if the base was ever changed (Phase 11)
/// those snapshots are intentionally NOT rewritten (§6), so the label reflects
/// the current base while the totals reflect their historical base. For a single
/// base (TRY) this caveat is invisible.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<SummaryData> summary = ref.watch(summaryProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: summary.when(
          loading: () => const _SummarySkeleton(),
          error: (Object _, StackTrace _) => SizedBox(
            height: _kFigureRowHeight,
            child: Center(
              child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
            ),
          ),
          data: (SummaryData data) => _SummaryFigures(data: data),
        ),
      ),
    );
  }
}

const double _kFigureRowHeight = 56;

class _SummaryFigures extends ConsumerWidget {
  const _SummaryFigures({required this.data});

  final SummaryData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final CurrencyService currency = ref.watch(currencyServiceProvider);
    final String base = ref.watch(baseCurrencyProvider);

    // Net takes the income accent when >= 0, the expense accent when negative.
    final Color netColor =
        data.netMinor >= 0 ? semantic.income : semantic.expense;

    return Row(
      children: <Widget>[
        Expanded(
          child: _Figure(
            label: l10n.summaryIncome,
            value: currency.format(data.incomeMinor, base),
            color: semantic.income,
          ),
        ),
        Expanded(
          child: _Figure(
            label: l10n.summaryExpense,
            value: currency.format(data.expenseMinor, base),
            color: semantic.expense,
          ),
        ),
        Expanded(
          child: _Figure(
            label: l10n.summaryNet,
            value: currency.format(data.netMinor, base),
            color: netColor,
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: semantic.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
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

/// A lightweight loading placeholder matching the figure row's height so the
/// card does not jump when the first value arrives.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _kFigureRowHeight,
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
