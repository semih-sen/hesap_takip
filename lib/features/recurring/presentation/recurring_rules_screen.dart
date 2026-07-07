import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/undo/entity_actions.dart';
import '../../../core/undo/undo_service.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/undo_snackbar.dart';
import '../application/recurring_providers.dart';
import '../services/recurring_service.dart';
import 'recurring_rule_form_page.dart';

/// Recurring-rules home (Phase 10): the list of rules with add/edit/delete,
/// inline pause/resume, and a manual "generate now" app-bar action. Delete is
/// routed through the existing [UndoService]; pause/resume is immediate (no undo,
/// matching category archive-toggle).
class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecurringRuleFormPage()),
    );
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int count = await ref
        .read(recurringServiceProvider)
        .generateDueEntries(DateTime.now());
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? l10n.recurringGeneratedCount(count)
                : l10n.recurringGeneratedNone,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<RecurringRule>> rulesAsync = ref.watch(
      recurringRulesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recurringTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.recurringGenerateNow,
            icon: const Icon(Icons.sync),
            onPressed: () => _generateNow(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringAdd),
      ),
      body: SafeArea(
        child: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) =>
              Center(child: Text(l10n.errorGeneric)),
          data: (List<RecurringRule> rules) {
            if (rules.isEmpty) {
              return _EmptyState(
                title: l10n.recurringEmptyTitle,
                message: l10n.recurringEmptyMessage,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl * 2,
              ),
              itemCount: rules.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) => _RuleRow(
                key: ValueKey<int>(rules[index].id),
                rule: rules[index],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A single recurring-rule row: name, wallet-amount, frequency summary, an
/// active/paused indicator, and an overflow menu (edit / pause-resume / delete).
class _RuleRow extends ConsumerWidget {
  const _RuleRow({super.key, required this.rule});

  final RecurringRule rule;

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecurringRuleFormPage(rule: rule),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label = l10n.recurringDeleted;
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(DeleteRecurringRuleAction(rule: rule, label: label));
    if (pendingId == null || !context.mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
  }

  Future<void> _togglePause(WidgetRef ref) async {
    await ref
        .read(recurringRepositoryProvider)
        .setActive(rule.id, !rule.isActive);
  }

  String _frequencySummary(AppLocalizations l10n) {
    final String unit = switch (rule.frequency) {
      RecurrenceFrequency.daily => l10n.recurringUnitDay,
      RecurrenceFrequency.weekly => l10n.recurringUnitWeek,
      RecurrenceFrequency.monthly => l10n.recurringUnitMonth,
      RecurrenceFrequency.yearly => l10n.recurringUnitYear,
    };
    final String base = l10n.recurringSummaryEvery(rule.interval, unit);
    if ((rule.frequency == RecurrenceFrequency.monthly ||
            rule.frequency == RecurrenceFrequency.yearly) &&
        rule.byMonthDay != null) {
      return '$base · ${l10n.recurringSummaryMonthDay(rule.byMonthDay!)}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CurrencyService currencyService = ref.watch(currencyServiceProvider);
    final String amountText = currencyService.format(
      rule.amount.minorUnits,
      rule.currencyCode,
    );
    final String sign = rule.flowDirection == FlowDirection.inflow ? '+' : '−';

    return Opacity(
      opacity: rule.isActive ? 1 : 0.55,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Icon(
          rule.isActive ? Icons.loop : Icons.pause_circle_outline,
          color: rule.isActive
              ? theme.colorScheme.primary
              : AppColors.textMuted,
        ),
        title: Row(
          children: <Widget>[
            Flexible(child: Text(rule.name, overflow: TextOverflow.ellipsis)),
            if (!rule.isActive) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.recurringPausedBadge,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$sign$amountText · ${_frequencySummary(l10n)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_RuleMenu>(
          onSelected: (_RuleMenu value) {
            switch (value) {
              case _RuleMenu.edit:
                _edit(context);
              case _RuleMenu.pause:
                _togglePause(ref);
              case _RuleMenu.delete:
                _delete(context, ref);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<_RuleMenu>>[
            PopupMenuItem<_RuleMenu>(
              value: _RuleMenu.edit,
              child: Text(l10n.actionEdit),
            ),
            PopupMenuItem<_RuleMenu>(
              value: _RuleMenu.pause,
              child: Text(
                rule.isActive
                    ? l10n.recurringActionPause
                    : l10n.recurringActionResume,
              ),
            ),
            PopupMenuItem<_RuleMenu>(
              value: _RuleMenu.delete,
              child: Text(l10n.actionDelete),
            ),
          ],
        ),
        onTap: () => _edit(context),
      ),
    );
  }
}

enum _RuleMenu { edit, pause, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.loop, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
