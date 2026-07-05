import 'package:freezed_annotation/freezed_annotation.dart';

part 'summary_data.freezed.dart';

/// The 9-cell dashboard summary (PROJECT_PLAN §8.3 / Summary Card Refactor).
///
/// Every monetary field is in **base-currency minor units**, summed from the
/// snapshotted `baseAmountMinor` column — never recomputed from a live rate
/// (Flag A-2). [baseCurrencyCode] is the current base, carried so the widget
/// formats without another provider read.
///
/// Intentional mixed basis (do NOT "fix"):
/// - [currentCashMinor] is **cash basis** — completed only, as of today.
/// - [carriedOverMinor] / [carryForwardMinor] are **projection basis** —
///   completed + pending at the period boundaries.
@freezed
sealed class SummaryData with _$SummaryData {
  const factory SummaryData({
    required String baseCurrencyCode,
    // Row 1 — running balances (base minor units).
    required int carriedOverMinor, // Devreden
    required int currentCashMinor, // Bugünkü Kasa
    required int carryForwardMinor, // Devredecek
    // Row 2 — period flows (base minor units).
    required int incomeTotalMinor, // Gelir
    required int expenseTotalMinor, // Gider
    required int netBalanceMinor, // Bakiye
    // Row 3 — breakdown (base minor units).
    required int collectedIncomeMinor, // Tahsilat (completed income)
    required int receivableIncomeMinor, // Alacak   (pending income)
    required int paidExpenseMinor, // Ödeme    (completed expense)
    required int payableExpenseMinor, // Borç     (pending expense)
  }) = _SummaryData;

  const SummaryData._();

  /// An all-zero card for the empty/loading fallback under [baseCurrencyCode].
  factory SummaryData.zero(String baseCurrencyCode) => SummaryData(
    baseCurrencyCode: baseCurrencyCode,
    carriedOverMinor: 0,
    currentCashMinor: 0,
    carryForwardMinor: 0,
    incomeTotalMinor: 0,
    expenseTotalMinor: 0,
    netBalanceMinor: 0,
    collectedIncomeMinor: 0,
    receivableIncomeMinor: 0,
    paidExpenseMinor: 0,
    payableExpenseMinor: 0,
  );

  /// Row-2 Gelir must equal Tahsilat + Alacak (invariant, asserted in tests).
  int get incomeTotalCheckMinor =>
      collectedIncomeMinor + receivableIncomeMinor;

  /// Row-2 Gider must equal Ödeme + Borç (invariant, asserted in tests).
  int get expenseTotalCheckMinor => paidExpenseMinor + payableExpenseMinor;
}
