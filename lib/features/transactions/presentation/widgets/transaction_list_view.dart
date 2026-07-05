import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/date/app_date.dart';
import '../../../../core/undo/entity_actions.dart';
import '../../../../core/undo/undo_service.dart';
import '../../../../data/models/transaction.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/undo_snackbar.dart';
import '../../application/transactions_providers.dart';
import '../transaction_date_group.dart';
import '../transaction_form_page.dart';
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

  void _edit(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionFormPage(transactionId: id),
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
              SliverMainAxisGroup(
                slivers: <Widget>[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DateHeaderDelegate(
                      label: transactionDateGroupLabel(
                        group.date,
                        today: today,
                        l10n: l10n,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    sliver: SliverList.separated(
                      itemCount: group.rows.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (BuildContext context, int index) {
                        final TransactionListRow row = group.rows[index];
                        return InkWell(
                          key: ValueKey<int>(row.id),
                          borderRadius: AppRadius.mdAll,
                          onTap: () => _edit(row.id),
                          onLongPress: () => _delete(row),
                          child: TransactionListItem(row: row),
                        );
                      },
                    ),
                  ),
                ],
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xxl * 2),
            ),
          ],
        );
      },
    );
  }
}

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
