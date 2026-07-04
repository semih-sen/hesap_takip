import 'package:drift/drift.dart' show Value;

import '../../../core/currency/money.dart';
import '../../database/app_database.dart' as db;
import '../recurring_rule.dart';

/// Mappers between the Drift `RecurringRules` row and the [RecurringRule]
/// domain model. Date-only columns round-trip via [db.RecurringRule]'s
/// `DateOnlyConverter` (Phase 2 Task 0).

extension RecurringRuleRowMapper on db.RecurringRule {
  RecurringRule toDomain() => RecurringRule(
    id: id,
    name: name,
    type: type,
    flowDirection: flowDirection,
    walletId: walletId,
    amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
    frequency: frequency,
    interval: interval,
    byMonthDay: byMonthDay,
    byWeekday: byWeekday,
    startDate: startDate,
    endDate: endDate,
    maxOccurrences: maxOccurrences,
    generatedCount: generatedCount,
    lastGeneratedDate: lastGeneratedDate,
    autoPost: autoPost,
    isActive: isActive,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension RecurringRuleDomainMapper on RecurringRule {
  db.RecurringRule toRow() => db.RecurringRule(
    id: id,
    name: name,
    type: type,
    flowDirection: flowDirection,
    walletId: walletId,
    amountMinor: amount.minorUnits,
    currencyCode: currencyCode,
    frequency: frequency,
    interval: interval,
    byMonthDay: byMonthDay,
    byWeekday: byWeekday,
    startDate: startDate,
    endDate: endDate,
    maxOccurrences: maxOccurrences,
    generatedCount: generatedCount,
    lastGeneratedDate: lastGeneratedDate,
    autoPost: autoPost,
    isActive: isActive,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  db.RecurringRulesCompanion toInsertCompanion() =>
      db.RecurringRulesCompanion.insert(
        name: name,
        type: type,
        flowDirection: flowDirection,
        walletId: walletId,
        amountMinor: amount.minorUnits,
        currencyCode: currencyCode,
        frequency: frequency,
        interval: Value(interval),
        byMonthDay: Value(byMonthDay),
        byWeekday: Value(byWeekday),
        startDate: startDate,
        endDate: Value(endDate),
        maxOccurrences: Value(maxOccurrences),
        generatedCount: Value(generatedCount),
        lastGeneratedDate: Value(lastGeneratedDate),
        autoPost: Value(autoPost),
        isActive: Value(isActive),
        note: Value(note),
      );
}
