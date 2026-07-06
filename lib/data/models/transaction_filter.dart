import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/date/date_range.dart';
import '../database/tables/enums.dart';

part 'transaction_filter.freezed.dart';

/// The **List scope** filter (PROJECT_PLAN §9). This is the transaction list's
/// own, independent state — it is intentionally decoupled from the Summary
/// scope (`SummaryWalletSelection`, Phase 7): the two never read or write each
/// other.
///
/// Every field narrows the list; the defaults ([TransactionFilter.initial])
/// narrow nothing (all wallets, all categories, all types/statuses, no date
/// bound, empty search). An empty [walletIds]/[categoryIds] means ALL, never
/// "none".
@freezed
abstract class TransactionFilter with _$TransactionFilter {
  const factory TransactionFilter({
    /// Inclusive date-only bound on `valueDate`; null = unbounded.
    DateRange? range,

    /// Wallets to include; empty = ALL wallets.
    @Default(<int>{}) Set<int> walletIds,

    /// Categories a transaction must be linked to; empty = ALL categories.
    @Default(<int>{}) Set<int> categoryIds,

    /// Restrict to a single [TransactionType]; null = any.
    TransactionType? type,

    /// Restrict to a single [TransactionStatus]; null = any.
    TransactionStatus? status,

    /// Free-text search over note / payee / category name; blank = no search.
    @Default('') String search,
  }) = _TransactionFilter;

  const TransactionFilter._();

  /// The default, unnarrowed filter: all wallets, everything visible.
  factory TransactionFilter.initial() => const TransactionFilter();

  /// Whether any predicate is narrowing the list (drives the app-bar filter
  /// badge). A blank/whitespace-only search does not count as active. [range] is
  /// intentionally EXCLUDED: it is driven by the always-on List period control
  /// (§C.3), not the filter sheet, so it must not permanently light the badge.
  bool get isActive =>
      walletIds.isNotEmpty ||
      categoryIds.isNotEmpty ||
      type != null ||
      status != null ||
      search.trim().isNotEmpty;
}
