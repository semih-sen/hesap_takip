import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/date/app_date.dart';
import '../../../core/date/date_range.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/summary_data.dart';
import '../services/summary_period_value.dart';
import 'transactions_providers.dart';

part 'summary_providers.g.dart';

/// SUMMARY SCOPE — the account ids the summary aggregates over. Empty = ALL
/// accounts (every wallet, including those of since-archived accounts, to
/// preserve historical integrity — see proactive flag F8).
///
/// Deliberately separate from the List scope's `TransactionListFilter`: this is
/// the "two-scope rule" (PROJECT_PLAN §9). This notifier never reads, watches,
/// or writes any list-scope provider, and vice-versa.
@riverpod
class SummaryAccountSelection extends _$SummaryAccountSelection {
  @override
  Set<int> build() => <int>{}; // default: all accounts

  /// Adds/removes [accountId], always emitting a NEW set so watchers rebuild.
  void toggle(int accountId) {
    final Set<int> next = <int>{...state};
    if (!next.remove(accountId)) {
      next.add(accountId);
    }
    state = next;
  }

  /// Selects ALL accounts (the empty-set sentinel).
  void selectAll() => state = <int>{};

  /// Replaces the selection with a defensive copy of [ids].
  void setSelection(Set<int> ids) => state = <int>{...ids};
}

/// SUMMARY SCOPE — the period the summary covers. Defaults to the current month
/// with endless month navigation, plus Last-30-days / All-time / Custom presets.
@riverpod
class SummaryPeriod extends _$SummaryPeriod {
  @override
  SummaryPeriodValue build() => SummaryPeriodValue.month(AppDate.today());

  /// Moves to the next calendar month (endless).
  void nextMonth() => _stepMonth(1);

  /// Moves to the previous calendar month (endless).
  void previousMonth() => _stepMonth(-1);

  void _stepMonth(int delta) {
    final DateTime base = state.kind == SummaryPeriodKind.month
        ? state.anchor!
        : AppDate.today();
    _set(SummaryPeriodValue.month(DateTime(base.year, base.month + delta, 1)));
  }

  /// Switches to the 30-day window ending today.
  void setLast30Days() => _set(SummaryPeriodValue.last30Days(AppDate.today()));

  /// Switches to the all-time window.
  void setAllTime() => _set(const SummaryPeriodValue.allTime());

  /// Switches to a user-picked explicit [range].
  void setCustomRange(DateRange range) =>
      _set(SummaryPeriodValue.custom(range));

  void _set(SummaryPeriodValue value) {
    state = value;
    // Push into the List filter so the paging window resets and `filter.range`
    // mirrors the shared period.
    ref.read(transactionListFilterProvider.notifier).setDateRange(value.range);
  }
}

/// Derived, reactive 9-cell base-currency summary. Watches BOTH summary-scope
/// providers (account selection + period) plus the wallet list and base currency
/// (so archiving/adding a wallet or changing the base re-resolves) — and NOTHING
/// from the List scope (the two-scope rule holds).
///
/// The account selection is resolved to the underlying non-archived wallet ids
/// here (D1): the repository then treats an empty set as ALL non-archived
/// wallets. A NON-empty account selection that resolves to NO wallets
/// short-circuits to a zero card rather than falling through to "all".
@riverpod
Stream<SummaryData> summary(Ref ref) async* {
  final Set<int> accountSelection = ref.watch(summaryAccountSelectionProvider);
  final DateRange range = ref.watch(summaryPeriodProvider).range;
  final String base = ref.watch(baseCurrencyProvider);
  final List<Wallet> wallets =
      ref.watch(allWalletsProvider).value ?? const <Wallet>[];
  final TransactionRepository repo = ref.watch(transactionRepositoryProvider);
  final DateTime today = AppDate.today();

  if (accountSelection.isEmpty) {
    // ALL accounts → empty wallet set → repo resolves to all non-archived.
    yield* repo.watchSummary(
      walletIds: const <int>{},
      period: range,
      today: today,
    );
    return;
  }

  final Set<int> resolvedWalletIds = <int>{
    for (final Wallet w in wallets)
      if (!w.isArchived && accountSelection.contains(w.accountId)) w.id,
  };

  if (resolvedWalletIds.isEmpty) {
    // Explicit selection but no (active) wallets under it → zero, NOT "all".
    yield SummaryData.zero(base);
    return;
  }

  yield* repo.watchSummary(
    walletIds: resolvedWalletIds,
    period: range,
    today: today,
  );
}
