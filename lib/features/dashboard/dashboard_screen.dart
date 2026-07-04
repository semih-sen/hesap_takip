import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/undo/entity_actions.dart';
import '../../core/undo/undo_service.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/undo_snackbar.dart';
import '../transactions/application/transactions_providers.dart';
import '../transactions/presentation/transaction_form_page.dart';
import '../transactions/presentation/widgets/transaction_list_item.dart';

/// Dashboard (Phase 5 first pass): hosts the transaction list across all wallets
/// with a FAB to add. Tap a row to edit; long-press to delete via the undo
/// queue. The Summary card and List/Summary filtering scopes arrive in
/// Phase 6/7 and are intentionally not built here.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TransactionFormPage()),
    );
  }

  void _edit(BuildContext context, int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionFormPage(transactionId: id),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TransactionListRow row,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final Transaction? txn = await repo.findTransaction(row.id);
    if (txn == null || !context.mounted) {
      return;
    }
    final String label = l10n.transactionDeleted;
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(DeleteTransactionAction(transaction: txn, label: label));
    if (pendingId == null || !context.mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<TransactionListRow>> stream = ref.watch(
      transactionListProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.transactionAdd),
      ),
      body: stream.when(
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl * 2,
            ),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final TransactionListRow row = rows[index];
              return InkWell(
                key: ValueKey<int>(row.id),
                borderRadius: AppRadius.mdAll,
                onTap: () => _edit(context, row.id),
                onLongPress: () => _delete(context, ref, row),
                child: TransactionListItem(row: row),
              );
            },
          );
        },
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
