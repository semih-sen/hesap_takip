import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/date/app_date.dart';
import '../../../core/date/date_range.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/summary_data.dart';
import '../services/summary_period_value.dart';

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
    state = SummaryPeriodValue.month(DateTime(base.year, base.month + delta, 1));
  }

  /// Switches to the 30-day window ending today.
  void setLast30Days() => state = SummaryPeriodValue.last30Days(AppDate.today());

  /// Switches to the all-time window.
  void setAllTime() => state = const SummaryPeriodValue.allTime();

  /// Switches to a user-picked explicit [range].
  void setCustomRange(DateRange range) =>
      state = SummaryPeriodValue.custom(range);
}

/// Derived, reactive base-currency summary. Watches BOTH summary-scope providers
/// (account selection + period) and the repository — nothing from the List scope.
///
/// Empty account selection ⇒ empty wallet set ⇒ ALL wallets (the DAO omits the
/// wallet predicate). A NON-empty selection that resolves to NO wallets (e.g. an
/// account with no wallets) short-circuits to [SummaryData.zero] rather than
/// falling through to the empty-set-means-all branch.
@riverpod
Stream<SummaryData> summary(Ref ref) async* {
  final Set<int> accountSelection = ref.watch(summaryAccountSelectionProvider);
  final DateRange range = ref.watch(summaryPeriodProvider).range;
  final TransactionRepository repo = ref.watch(transactionRepositoryProvider);

  if (accountSelection.isEmpty) {
    // ALL accounts: pass an empty wallet set so the DAO adds no wallet predicate.
    yield* repo.watchSummary(walletIds: const <int>{}, period: range);
    return;
  }

  // Resolve the selected accounts to their wallet ids, reactively.
  final List<Wallet> wallets =
      ref.watch(allWalletsProvider).asData?.value ?? const <Wallet>[];
  final Set<int> resolvedWalletIds = <int>{
    for (final Wallet w in wallets)
      if (accountSelection.contains(w.accountId)) w.id,
  };

  if (resolvedWalletIds.isEmpty) {
    // Explicit non-empty account selection but no wallets under it → zero, NOT
    // "all" (do not fall into the empty-set-means-all branch above).
    yield SummaryData.zero;
    return;
  }

  yield* repo.watchSummary(walletIds: resolvedWalletIds, period: range);
}
