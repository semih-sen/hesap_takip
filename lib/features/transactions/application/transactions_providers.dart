import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/date/date_range.dart';
import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/database/daos/transaction_dao.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/transaction_filter.dart';
import '../../../data/repositories/transaction_repository.dart';

part 'transactions_providers.g.dart';

/// One category chip on a list row (name + color dot), for Row 3 of the bespoke
/// item. Immutable and const-friendly so the widget stays provider-free.
class CategoryChipData {
  const CategoryChipData({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final int id;
  final String name;

  /// ARGB int color for the chip's leading dot.
  final int colorValue;
}

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
    required this.status,
    required this.walletName,
    required this.valueDate,
    required this.accentColorValue,
    this.note,
    this.payee,
    this.categories = const <CategoryChipData>[],
    this.plannedAmountMinor,
    this.settledAmountMinor,
    this.isPendingParent = false,
    this.counterWalletName,
    this.isRecurring = false,
  });

  final int id;

  /// Primary category name, else payee; null → widget uses the type label.
  final String? title;
  final int amountMinor;
  final String currencyCode;
  final FlowDirection flowDirection;
  final TransactionType type;
  final TransactionStatus status;
  final String walletName;
  final DateTime valueDate;

  /// ARGB int: the primary category color, else the type's semantic accent.
  final int accentColorValue;
  final String? note;
  final String? payee;

  /// Categories for Row 3 chips, primary-first.
  final List<CategoryChipData> categories;

  // ---- Contextual Row-3 seams (populated by Phases 8–10) ----
  final int? plannedAmountMinor;
  final int? settledAmountMinor;
  final bool isPendingParent;
  final String? counterWalletName;
  final bool isRecurring;
}

/// Semantic accent (ARGB int) for a transaction with no category color.
int _accentForType(TransactionType type) => switch (type) {
  TransactionType.income => AppColors.income.toARGB32(),
  TransactionType.expense => AppColors.expense.toARGB32(),
  TransactionType.transfer => AppColors.transfer.toARGB32(),
};

TransactionListRow _toRow(TransactionListRowData d) {
  final TransactionRowCategory? primary = d.categories.isEmpty
      ? null
      : d.categories.first;
  return TransactionListRow(
    id: d.id,
    title: primary?.name ?? d.payee,
    amountMinor: d.amountMinor,
    currencyCode: d.currencyCode,
    flowDirection: d.flowDirection,
    type: d.type,
    status: d.status,
    walletName: d.walletName,
    valueDate: d.valueDate,
    accentColorValue: primary?.colorValue ?? _accentForType(d.type),
    note: d.note,
    payee: d.payee,
    categories: <CategoryChipData>[
      for (final TransactionRowCategory c in d.categories)
        CategoryChipData(id: c.id, name: c.name, colorValue: c.colorValue),
    ],
    plannedAmountMinor: d.plannedAmountMinor,
    settledAmountMinor: d.settledAmountMinor,
    isPendingParent: d.isPendingParent,
    counterWalletName: d.counterWalletName,
    isRecurring: d.isRecurring,
  );
}

/// Page size for the transaction list's growing-window pagination. The query is
/// bounded to `pageSize * visiblePageCount` so a 5k-row ledger is never streamed
/// unbounded (PROJECT_PLAN Phase 6, §B.4/§B.5).
const int kTransactionPageSize = 50;

/// The **List scope** filter state (PROJECT_PLAN §9). This is a standalone
/// provider — it never reads from or writes to the Summary scope
/// (`SummaryWalletSelection`, Phase 7). Every setter narrows/relaxes exactly one
/// facet; [reset] restores the unnarrowed default.
@riverpod
class TransactionListFilter extends _$TransactionListFilter {
  @override
  TransactionFilter build() => TransactionFilter.initial();

  void setDateRange(DateRange? range) => state = state.copyWith(range: range);

  void setWallets(Set<int> ids) =>
      state = state.copyWith(walletIds: Set<int>.of(ids));

  void setCategories(Set<int> ids) =>
      state = state.copyWith(categoryIds: Set<int>.of(ids));

  void setType(TransactionType? type) => state = state.copyWith(type: type);

  void setStatus(TransactionStatus? status) =>
      state = state.copyWith(status: status);

  void setSearch(String query) => state = state.copyWith(search: query);

  void reset() => state = TransactionFilter.initial();
}

/// The number of pages currently loaded into the list (growing window). Resets
/// to 1 whenever the filter changes (it `watch`es the filter), so narrowing the
/// list starts from the top rather than keeping a stale large window.
@riverpod
class TransactionListWindow extends _$TransactionListWindow {
  @override
  int build() {
    ref.watch(transactionListFilterProvider);
    return 1;
  }

  /// Grows the window by one page (called as the user nears the list's end).
  void loadMore() => state = state + 1;
}

/// Reactive, newest-first rows for the current List filter, bounded to the
/// current window. Rebuilds when the filter or the window changes; the Undo
/// overlay is layered on top by [visibleTransactions] (never here).
@riverpod
Stream<List<TransactionListRow>> transactionList(Ref ref) {
  final TransactionFilter filter = ref.watch(transactionListFilterProvider);
  final int pageCount = ref.watch(transactionListWindowProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionRows(filter, limit: kTransactionPageSize * pageCount)
      .map(
        (List<TransactionListRowData> rows) =>
            rows.map(_toRow).toList(growable: false),
      );
}

/// Rows as the user should SEE them = the DB stream with the pending-undo
/// overlay applied (a queued delete disappears instantly, reappears on undo).
/// The overlay sits ON TOP of the filtered/paginated stream so it survives the
/// new pipeline unchanged (PROJECT_PLAN Phase 6, proactive flag 3).
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
