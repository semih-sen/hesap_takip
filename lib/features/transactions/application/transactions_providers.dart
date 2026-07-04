import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/database/daos/transaction_dao.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/repositories/transaction_repository.dart';

part 'transactions_providers.g.dart';

/// Immutable, presentational view-model for one transaction-list row.
///
/// Built from the DAO's denormalized [TransactionListRowData]; the bespoke
/// `TransactionListItem` widget renders it directly with no further provider
/// reads. [title] is null when the transaction has neither a category nor a
/// payee — the widget then falls back to the localized type label.
class TransactionListRow {
  const TransactionListRow({
    required this.id,
    required this.title,
    required this.amountMinor,
    required this.currencyCode,
    required this.flowDirection,
    required this.type,
    required this.walletName,
    required this.valueDate,
    required this.accentColorValue,
    this.note,
    this.payee,
  });

  final int id;

  /// Primary category name, else payee; null → widget uses the type label.
  final String? title;
  final int amountMinor;
  final String currencyCode;
  final FlowDirection flowDirection;
  final TransactionType type;
  final String walletName;
  final DateTime valueDate;

  /// ARGB int: the primary category color, else the type's semantic accent.
  final int accentColorValue;
  final String? note;
  final String? payee;
}

/// Semantic accent (ARGB int) for a transaction with no category color.
int _accentForType(TransactionType type) => switch (type) {
  TransactionType.income => AppColors.income.toARGB32(),
  TransactionType.expense => AppColors.expense.toARGB32(),
  TransactionType.transfer => AppColors.transfer.toARGB32(),
};

TransactionListRow _toRow(TransactionListRowData d) => TransactionListRow(
  id: d.id,
  title: d.primaryCategoryName ?? d.payee,
  amountMinor: d.amountMinor,
  currencyCode: d.currencyCode,
  flowDirection: d.flowDirection,
  type: d.type,
  walletName: d.walletName,
  valueDate: d.valueDate,
  accentColorValue: d.primaryCategoryColorValue ?? _accentForType(d.type),
  note: d.note,
  payee: d.payee,
);

/// Reactive, newest-first list rows across ALL wallets (PROJECT_PLAN §5.4).
/// The two-scope List/Summary filtering is Phase 6/7 — not built here.
@riverpod
Stream<List<TransactionListRow>> transactionList(Ref ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionList()
      .map(
        (List<TransactionListRowData> rows) =>
            rows.map(_toRow).toList(growable: false),
      );
}

/// Rows as the user should SEE them = the DB stream with the pending-undo
/// overlay applied (a queued delete disappears instantly, reappears on undo).
@riverpod
List<TransactionListRow> visibleTransactions(Ref ref) {
  final List<TransactionListRow> base =
      ref.watch(transactionListProvider).asData?.value ??
      const <TransactionListRow>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<TransactionListRow>(
    base: base,
    queue: queue,
    refOf: (TransactionListRow r) =>
        EntityRef(UndoEntityType.transaction, r.id),
  );
}
