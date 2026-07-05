import 'package:flutter/foundation.dart';

/// Immutable base-currency totals for the Summary scope (PROJECT_PLAN §8.3).
///
/// Every field is in base-currency **minor units**, summed from the snapshotted
/// `base_amount_minor` column (never recomputed from a live rate). [incomeMinor]
/// and [expenseMinor] are non-negative; [netMinor] is their signed difference.
@immutable
class SummaryData {
  const SummaryData({required this.incomeMinor, required this.expenseMinor});

  /// Σ of `base_amount_minor` over completed, non-transfer income rows.
  final int incomeMinor;

  /// Σ of `base_amount_minor` over completed, non-transfer expense rows.
  final int expenseMinor;

  /// income − expense (may be negative).
  int get netMinor => incomeMinor - expenseMinor;

  /// The empty/loading fallback — all zeros.
  static const SummaryData zero = SummaryData(incomeMinor: 0, expenseMinor: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryData &&
          other.incomeMinor == incomeMinor &&
          other.expenseMinor == expenseMinor;

  @override
  int get hashCode => Object.hash(incomeMinor, expenseMinor);

  @override
  String toString() =>
      'SummaryData(income: $incomeMinor, expense: $expenseMinor)';
}
