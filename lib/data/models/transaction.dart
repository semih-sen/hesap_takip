import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/currency/money.dart';
import '../database/tables/enums.dart';

part 'transaction.freezed.dart';

/// Domain model for a ledger transaction (PROJECT_PLAN §5.2).
///
/// The transaction-currency value is [amount] (a [Money]). [baseAmountMinor] is
/// the snapshot in the *base* currency at write time; the base currency code is
/// not stored per row (it can change later without rewriting history, §6), so it
/// stays a raw minor-unit `int` rather than a [Money].
@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required int id,
    required int walletId,
    required TransactionType type,
    required FlowDirection flowDirection,
    required TransactionStatus status,
    required Money amount,
    required Decimal exchangeRateToBase,
    required int baseAmountMinor,
    required DateTime valueDate,
    String? note,
    String? payee,
    int? parentTransactionId,
    int? plannedAmountMinor,
    int? settledAmountMinor,
    int? settledContribMinor,
    int? recurringRuleId,
    String? transferGroupId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  /// The transaction's ISO 4217 currency code (from [amount]).
  String get currencyCode => amount.currencyCode;
}
