import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/currency/money.dart';
import '../database/tables/enums.dart';

part 'recurring_rule.freezed.dart';

/// Domain model for a recurring-transaction rule (PROJECT_PLAN §5.2).
///
/// Date fields (`startDate`, `endDate`, `lastGeneratedDate`) are date-only
/// concepts normalized to local midnight (§7, Phase 2 Task 0).
@freezed
abstract class RecurringRule with _$RecurringRule {
  const RecurringRule._();

  const factory RecurringRule({
    required int id,
    required String name,
    required TransactionType type,
    required FlowDirection flowDirection,
    required int walletId,
    required Money amount,
    required RecurrenceFrequency frequency,
    required int interval,
    int? byMonthDay,
    int? byWeekday,
    required DateTime startDate,
    DateTime? endDate,
    int? maxOccurrences,
    required int generatedCount,
    DateTime? lastGeneratedDate,
    required bool autoPost,
    required bool isActive,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RecurringRule;

  /// The rule's ISO 4217 currency code (from [amount]).
  String get currencyCode => amount.currencyCode;
}
