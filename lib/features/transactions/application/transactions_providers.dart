import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../core/date/date_range.dart';
import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/database/daos/transaction_dao.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/exchange_rate_entry.dart';
import '../../../data/models/transaction_filter.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/wallet.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/summary_period_value.dart';
import 'summary_providers.dart';

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
    required this.accountColorValue,
    this.note,
    this.payee,
    this.categories = const <CategoryChipData>[],
    this.isPending = false,
    this.isOverdue = false,
    this.counterWalletName,
    this.isRecurring = false,
    required this.baseAmountMinor,
    required this.baseCurrencyCode,
    this.equivalentAmountMinor,
    this.equivalentCurrencyCode,
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
  /// Drives the row's tinted background only.
  final int accentColorValue;

  /// ARGB int: the owning **account**'s color (`Wallet.accountId →
  /// Account.colorValue`). Drives the left stripe only — sourced independently
  /// of [accentColorValue] so the stripe says *which account* and the tint says
  /// *which category/type*.
  final int accountColorValue;
  final String? note;
  final String? payee;

  /// Categories for Row 3 chips, primary-first.
  final List<CategoryChipData> categories;

  // ---- Contextual Row-3 seams ----

  /// A future-dated (or overdue) unpaid income/expense = alacak/borç. Its
  /// `amountMinor` is the outstanding remainder; swipe settles it.
  final bool isPending;

  /// A [isPending] item whose due date is already in the past.
  final bool isOverdue;
  final String? counterWalletName;
  final bool isRecurring;

  /// The transaction amount converted to the app's base currency.
  final int baseAmountMinor;

  /// The app's base currency code (e.g. 'TRY') — used to format
  /// [baseAmountMinor] when it differs from [currencyCode].
  final String baseCurrencyCode;
  final int? equivalentAmountMinor;
  final String? equivalentCurrencyCode;
}

/// Semantic accent (ARGB int) for a transaction with no category color.
int _accentForType(TransactionType type) => switch (type) {
  TransactionType.income => AppColors.income.toARGB32(),
  TransactionType.expense => AppColors.expense.toARGB32(),
  TransactionType.transfer => AppColors.transfer.toARGB32(),
};

TransactionListRow _toRow(
  TransactionListRowData d,
  String baseCurrencyCode,
  String primaryCurrencyCode,
  List<ExchangeRateEntry> rates,
  CurrencyService currencyService,
) {
  final TransactionRowCategory? primary = d.categories.isEmpty
      ? null
      : d.categories.first;
  // Pending/overdue are DERIVED here (where "today" is known) and passed as
  // flags so the pure list item never reads a clock or a provider (§5.1).
  final bool isPending = d.status == TransactionStatus.pending;
  final bool isOverdue = isPending && d.valueDate.isBefore(AppDate.today());
  return TransactionListRow(
    id: d.id,
    title: d.note,
    amountMinor: d.amountMinor,
    currencyCode: d.currencyCode,
    flowDirection: d.flowDirection,
    type: d.type,
    status: d.status,
    walletName: d.walletName,
    valueDate: d.valueDate,
    accentColorValue: primary?.colorValue ?? _accentForType(d.type),
    accountColorValue: d.accountColorValue,
    note: d.note,
    payee: d.payee,
    categories: <CategoryChipData>[
      for (final TransactionRowCategory c in d.categories)
        CategoryChipData(id: c.id, name: c.name, colorValue: c.colorValue),
    ],
    isPending: isPending,
    isOverdue: isOverdue,
    counterWalletName: d.counterWalletName,
    isRecurring: d.isRecurring,
    baseAmountMinor: d.baseAmountMinor,
    baseCurrencyCode: baseCurrencyCode,
    equivalentAmountMinor: _equivalentAmountMinor(
      d,
      baseCurrencyCode,
      primaryCurrencyCode,
      rates,
      currencyService,
    ),
    equivalentCurrencyCode: primaryCurrencyCode,
  );
}

int? _equivalentAmountMinor(
  TransactionListRowData row,
  String baseCurrencyCode,
  String primaryCurrencyCode,
  List<ExchangeRateEntry> rates,
  CurrencyService currencyService,
) {
  if (row.currencyCode == primaryCurrencyCode ||
      !currencyService.isSupported(primaryCurrencyCode)) {
    return null;
  }
  if (primaryCurrencyCode == baseCurrencyCode) {
    return row.baseAmountMinor;
  }

  final double? directRate = _latestRate(
    rates,
    row.currencyCode,
    primaryCurrencyCode,
    row.valueDate,
  );
  if (directRate != null) {
    return currencyService.convertMinor(
      amountMinor: row.amountMinor,
      fromCode: row.currencyCode,
      toCode: primaryCurrencyCode,
      rate: directRate,
    );
  }

  final double? inverseRate = _latestRate(
    rates,
    primaryCurrencyCode,
    row.currencyCode,
    row.valueDate,
  );
  if (inverseRate != null && inverseRate != 0) {
    return currencyService.convertMinor(
      amountMinor: row.amountMinor,
      fromCode: row.currencyCode,
      toCode: primaryCurrencyCode,
      rate: 1 / inverseRate,
    );
  }

  final double? baseToPrimary = _latestRate(
    rates,
    baseCurrencyCode,
    primaryCurrencyCode,
    row.valueDate,
  );
  if (baseToPrimary != null) {
    return currencyService.convertMinor(
      amountMinor: row.baseAmountMinor,
      fromCode: baseCurrencyCode,
      toCode: primaryCurrencyCode,
      rate: baseToPrimary,
    );
  }

  final double? primaryToBase = _latestRate(
    rates,
    primaryCurrencyCode,
    baseCurrencyCode,
    row.valueDate,
  );
  if (primaryToBase != null && primaryToBase != 0) {
    return currencyService.convertMinor(
      amountMinor: row.baseAmountMinor,
      fromCode: baseCurrencyCode,
      toCode: primaryCurrencyCode,
      rate: 1 / primaryToBase,
    );
  }

  return null;
}

double? _latestRate(
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

  void setShowTransfers(bool show) =>
      state = state.copyWith(showTransfers: show);

  void setSearch(String query) => state = state.copyWith(search: query);

  void reset() => state = TransactionFilter.initial();
}

/// The number of pages currently loaded into the list (growing window). Resets
/// to 1 whenever the filter OR the period changes (it `watch`es both), so
/// narrowing the list or navigating months starts from the top rather than
/// keeping a stale large window.
@riverpod
class TransactionListWindow extends _$TransactionListWindow {
  @override
  int build() {
    ref.watch(transactionListFilterProvider);
    ref.watch(summaryPeriodProvider);
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
  final Set<int> accountSelection = ref.watch(summaryAccountSelectionProvider);
  final List<Wallet> allWallets =
      ref.watch(allWalletsProvider).value ?? const <Wallet>[];
  final SummaryPeriodValue period = ref.watch(summaryPeriodProvider);
  final int pageCount = ref.watch(transactionListWindowProvider);

  // The period is the authoritative date bound (derived here so scoping is
  // correct from the first frame, before any push into `filter.range`). When
  // the period contains today, overdue pending items dated before it are
  // carried forward so unpaid borç/alacak never fall out of view (§C.4).
  final DateTime today = AppDate.today();
  final DateRange range = period.range;
  final bool carryForward =
      !range.start.isAfter(today) && !range.end.isBefore(today);

  Set<int> resolvedWalletIds = filter.walletIds;
  if (accountSelection.isNotEmpty) {
    final Set<int> accountWalletIds = {
      for (final Wallet w in allWallets)
        if (!w.isArchived && accountSelection.contains(w.accountId)) w.id,
    };

    if (resolvedWalletIds.isNotEmpty) {
      resolvedWalletIds = resolvedWalletIds.intersection(accountWalletIds);
    } else {
      resolvedWalletIds = accountWalletIds;
    }
  }

  // Short-circuit if an account is selected but has no active wallets
  if (accountSelection.isNotEmpty && resolvedWalletIds.isEmpty) {
    return Stream<List<TransactionListRow>>.value(const <TransactionListRow>[]);
  }

  final TransactionFilter effective = filter.copyWith(
    range: range,
    walletIds: resolvedWalletIds,
  );
  final String baseCurrency = ref.watch(baseCurrencyProvider);
  final String primaryCurrency = ref.watch(primaryCurrencyProvider);
  final CurrencyService currencyService = ref.watch(currencyServiceProvider);
  final List<ExchangeRateEntry> rates =
      ref.watch(exchangeRateEntriesProvider).value ??
      const <ExchangeRateEntry>[];

  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionRows(
        effective,
        limit: kTransactionPageSize * pageCount,
        carryForwardOverdue: carryForward,
      )
      .map(
        (List<TransactionListRowData> rows) => rows
            .map(
              (TransactionListRowData d) => _toRow(
                d,
                baseCurrency,
                primaryCurrency,
                rates,
                currencyService,
              ),
            )
            .toList(growable: false),
      );
}

/// Rows as the user should SEE them = the DB stream with the pending-undo
/// overlay applied (a queued delete disappears instantly, reappears on undo).
/// The overlay sits ON TOP of the filtered/paginated stream so it survives the
/// new pipeline unchanged (PROJECT_PLAN Phase 6, proactive flag 3).
@riverpod
List<TransactionListRow> visibleTransactions(Ref ref) {
  final List<TransactionListRow> base =
      ref.watch(transactionListProvider).value ?? const <TransactionListRow>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<TransactionListRow>(
    base: base,
    queue: queue,
    refOf: (TransactionListRow r) =>
        EntityRef(UndoEntityType.transaction, r.id),
  );
}
