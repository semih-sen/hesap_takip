import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../core/date/app_date.dart';
import '../../../../core/undo/entity_actions.dart';
import '../../../../core/undo/undo_service.dart';
import '../../../../data/database/tables/enums.dart';
import '../../../../data/models/recurring_rule.dart';
import '../../../../data/models/transaction.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../recurring/presentation/recurring_rule_form_page.dart';
import '../../../shared/undo_snackbar.dart';
import '../../application/summary_providers.dart';
import '../../application/transactions_providers.dart';
import '../../services/summary_period_value.dart';
import '../transaction_date_group.dart';
import '../transaction_form_page.dart';
import '../transfer_form_page.dart';
import 'settle_sheet.dart';
import 'transaction_list_item.dart';

/// The transaction list body: date-grouped **sticky** sections built with
/// slivers only (a `CustomScrollView` of `SliverMainAxisGroup`s, each a pinned
/// `SliverPersistentHeader` + a `SliverList`; PROJECT_PLAN §B.4 — no new
/// package). Rows come from [visibleTransactionsProvider] (the filtered/
/// paginated DB stream with the Undo overlay on top). Nearing the end grows the
/// pagination window ([TransactionListWindow.loadMore]) so the query stays
/// bounded while remaining reactive.
class TransactionListView extends ConsumerStatefulWidget {
  const TransactionListView({super.key});

  @override
  ConsumerState<TransactionListView> createState() =>
      _TransactionListViewState();
}

class _TransactionListViewState extends ConsumerState<TransactionListView> {
  final ScrollController _controller = ScrollController();

  /// Load the next page when the user scrolls within this many pixels of the end.
  static const double _loadMoreThreshold = 600;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) {
      return;
    }
    final ScrollPosition pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      _maybeLoadMore();
    }
  }

  /// Grows the window only when the current page is full — i.e. the DB returned
  /// exactly `pageSize * pageCount` rows, so more may exist. Uses the pre-overlay
  /// base list so a transient pending-delete never stalls pagination.
  void _maybeLoadMore() {
    final List<TransactionListRow> base =
        ref.read(transactionListProvider).asData?.value ??
        const <TransactionListRow>[];
    final int pageCount = ref.read(transactionListWindowProvider);
    if (base.length >= kTransactionPageSize * pageCount) {
      ref.read(transactionListWindowProvider.notifier).loadMore();
    }
  }

  /// Opens the correct editor for [row]: transfers edit BOTH legs via the
  /// transfer form (routed by `transferGroupId`), everything else via the
  /// income/expense form.
  Future<void> _edit(TransactionListRow row) async {
    if (row.type == TransactionType.transfer) {
      final TransactionRepository repo = ref.read(
        transactionRepositoryProvider,
      );
      final Transaction? txn = await repo.findTransaction(row.id);
      final String? groupId = txn?.transferGroupId;
      if (groupId == null || !mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransferFormPage(transferGroupId: groupId),
        ),
      );
      return;
    }
    // A recurring-generated row asks the series-edit scope first (§8.4): "this
    // occurrence only" detaches it into a one-off; "this and future" ends the
    // rule here and opens a replacement rule form.
    if (row.isRecurring) {
      final TransactionRepository repo = ref.read(
        transactionRepositoryProvider,
      );
      final Transaction? txn = await repo.findTransaction(row.id);
      if (txn == null || !mounted) {
        return;
      }
      if (txn.recurringRuleId != null) {
        final _SeriesScope? scope = await _askSeriesScope();
        if (scope == null || !mounted) {
          return; // cancelled
        }
        if (scope == _SeriesScope.thisAndFuture) {
          await _editThisAndFuture(txn);
          return;
        }
        // "This occurrence only": detach, then fall through to the normal edit.
        await repo.detachFromRecurringRule(txn.id);
        if (!mounted) {
          return;
        }
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionFormPage(transactionId: row.id),
      ),
    );
  }

  /// Prompts the this-only / this-and-future series-edit choice.
  Future<_SeriesScope?> _askSeriesScope() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<_SeriesScope>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.recurringEditScopeTitle),
        content: Text(l10n.recurringEditScopeMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_SeriesScope.thisOnly),
            child: Text(l10n.recurringEditScopeThisOnly),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_SeriesScope.thisAndFuture),
            child: Text(l10n.recurringEditScopeThisAndFuture),
          ),
        ],
      ),
    );
  }

  /// "This and future": cap the current rule the day before this occurrence,
  /// remove this occurrence, then open a replacement rule (prefilled) starting
  /// here — it regenerates this occurrence and all future ones with the edited
  /// parameters. Already-generated PAST occurrences are never touched (§8.4).
  Future<void> _editThisAndFuture(Transaction txn) async {
    final RecurringRepository recurringRepo = ref.read(
      recurringRepositoryProvider,
    );
    final RecurringRule? rule = await recurringRepo.findRule(
      txn.recurringRuleId!,
    );
    if (rule == null || !mounted) {
      return;
    }
    final DateTime occurrenceDate = AppDate.dateOnly(txn.valueDate);
    await recurringRepo.setEndDate(
      rule.id,
      occurrenceDate.subtract(const Duration(days: 1)),
    );
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(txn.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecurringRuleFormPage.replacing(
          template: rule,
          startDate: occurrenceDate,
        ),
      ),
    );
  }

  Future<void> _delete(TransactionListRow row) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final Transaction? txn = await repo.findTransaction(row.id);
    if (txn == null || !mounted) {
      return;
    }

    // A transfer deletes BOTH legs as one undoable command (Flag B-1).
    final String? groupId = txn.transferGroupId;
    if (txn.type == TransactionType.transfer && groupId != null) {
      final List<Transaction> legs = await repo.transferLegs(groupId);
      if (legs.length != 2 || !mounted) {
        return;
      }
      final String transferLabel = l10n.transferDeleted;
      final String? transferPendingId = await ref
          .read(undoServiceProvider)
          .enqueue(
            DeleteTransferAction(
              transferGroupId: groupId,
              legTransactionIds: <int>[for (final Transaction l in legs) l.id],
              label: transferLabel,
            ),
          );
      if (transferPendingId == null || !mounted) {
        return;
      }
      showUndoSnackBar(
        context,
        ref,
        pendingId: transferPendingId,
        message: transferLabel,
      );
      return;
    }

    final String label = l10n.transactionDeleted;
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(DeleteTransactionAction(transaction: txn, label: label));
    if (pendingId == null || !mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CurrencyService currencyService = ref.watch(currencyServiceProvider);
    final AsyncValue<List<TransactionListRow>> stream = ref.watch(
      transactionListProvider,
    );

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
        ),
      ),
      data: (_) {
        final List<TransactionListRow> rows = ref.watch(
          visibleTransactionsProvider,
        );
        if (rows.isEmpty) {
          return _EmptyState(
            title: l10n.transactionsEmptyTitle,
            message: l10n.transactionsEmptyMessage,
          );
        }
        final List<TransactionDateGroup> groups = groupTransactionsByDate(rows);
        final DateTime today = AppDate.today();

        return CustomScrollView(
          controller: _controller,
          slivers: <Widget>[
            for (final TransactionDateGroup group in groups)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                sliver: SliverList.separated(
                  itemCount: group.rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final TransactionListRow row = group.rows[index];
                    final Widget tile = InkWell(
                      borderRadius: AppRadius.mdAll,
                      onTap: () => _edit(row),
                      onLongPress: () => _delete(row),
                      child: TransactionListItem(row: row, currency: currencyService),
                    );
                    // Only pending income/expense are swipe-settleable
                    // ("Öde"/"Tahsil et"); everything else renders plainly.
                    final bool settleable =
                        row.isPending &&
                        (row.type == TransactionType.income ||
                            row.type == TransactionType.expense);
                    if (!settleable) {
                      return KeyedSubtree(
                        key: ValueKey<int>(row.id),
                        child: tile,
                      );
                    }
                    return Dismissible(
                      key: ValueKey<String>('settle_${row.id}'),
                      background: _SettleSwipeBackground(
                        row: row,
                        alignEnd: false,
                      ),
                      secondaryBackground: _SettleSwipeBackground(
                        row: row,
                        alignEnd: true,
                      ),
                      confirmDismiss: (DismissDirection _) async {
                        await showSettleSheet(context, ref, row);
                        // Never actually dismiss — the list updates
                        // reactively from the DB after settling.
                        return false;
                      },
                      child: tile,
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Clearance for docked FAB
            ),
          ],
        );
      },
    );
  }
}

/// The user's choice in the recurring series-edit dialog.
enum _SeriesScope { thisOnly, thisAndFuture }

/// Pinned, opaque section header for a date group. Fixed-height so `minExtent ==
/// maxExtent` (no resize on scroll); its opaque background occludes rows sliding
/// underneath it.
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({required this.label});

  final String label;

  static const double _height = 38;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    return Container(
      height: _height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      color: theme.scaffoldBackgroundColor,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: semantic.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

/// The revealed swipe action behind a pending row: "Öde" (expense) / "Tahsil et"
/// (income) with the matching semantic accent, on either swipe direction.
class _SettleSwipeBackground extends StatelessWidget {
  const _SettleSwipeBackground({required this.row, required this.alignEnd});

  final TransactionListRow row;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final bool isIncome = row.type == TransactionType.income;
    final Color accent = isIncome ? semantic.income : semantic.expense;
    final String label = isIncome
        ? l10n.settleCollectTitle
        : l10n.settlePayTitle;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.20),
        borderRadius: AppRadius.mdAll,
      ),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(isIncome ? Icons.savings_outlined : Icons.payments_outlined,
              color: accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
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

/// A small caption shown only when overdue pending items dated BEFORE the
/// current period are actually being carried into the visible list (§C.5).
/// Computed client-side from the already-loaded rows — no extra query.
class TransactionListOverdueNotice extends ConsumerWidget {
  const TransactionListOverdueNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SummaryPeriodValue period = ref.watch(summaryPeriodProvider);
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
