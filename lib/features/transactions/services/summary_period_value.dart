import 'package:flutter/foundation.dart';

import '../../../core/date/app_date.dart';
import '../../../core/date/date_range.dart';

/// Which kind of period the Summary scope currently covers.
enum SummaryPeriodKind { month, last30Days, allTime, custom }

/// The period the Summary aggregates over, resolvable to an inclusive,
/// date-only [DateRange] (PROJECT_PLAN §7 / Phase 7, D3).
///
/// Bounds are always constructed date-only (`DateTime(y, m, d)`) so month ends
/// clamp correctly (Feb → 28/29) and nothing drifts across DST — see proactive
/// flag F7. `month` carries an [anchor] (any day within the month); `last30Days`
/// carries the reference "today" as [anchor]; `allTime` needs neither; `custom`
/// carries an explicit [customRange].
@immutable
class SummaryPeriodValue {
  const SummaryPeriodValue._(this.kind, {this.anchor, this.customRange});

  /// A calendar month, identified by any day within it (normalized to date-only).
  factory SummaryPeriodValue.month(DateTime anchor) =>
      SummaryPeriodValue._(SummaryPeriodKind.month, anchor: AppDate.dateOnly(anchor));

  /// The 30 days ending on [today] (inclusive). [today] defaults to now, but is
  /// injectable for deterministic tests.
  factory SummaryPeriodValue.last30Days([DateTime? today]) =>
      SummaryPeriodValue._(
        SummaryPeriodKind.last30Days,
        anchor: AppDate.dateOnly(today ?? DateTime.now()),
      );

  /// Every historical row — the widest representable date-only span.
  const SummaryPeriodValue.allTime()
      : this._(SummaryPeriodKind.allTime);

  /// A user-picked explicit range.
  factory SummaryPeriodValue.custom(DateRange range) =>
      SummaryPeriodValue._(SummaryPeriodKind.custom, customRange: range);

  final SummaryPeriodKind kind;

  /// For [SummaryPeriodKind.month]: a day within the month. For
  /// [SummaryPeriodKind.last30Days]: the reference "today". Null otherwise.
  final DateTime? anchor;

  /// The explicit range for [SummaryPeriodKind.custom]; null otherwise.
  final DateRange? customRange;

  /// The inclusive, date-only [DateRange] this period resolves to.
  DateRange get range {
    switch (kind) {
      case SummaryPeriodKind.month:
        final DateTime a = anchor!;
        // Day 0 of the next month == last day of this month (clamps Feb/leap).
        return DateRange(
          start: DateTime(a.year, a.month, 1),
          end: DateTime(a.year, a.month + 1, 0),
        );
      case SummaryPeriodKind.last30Days:
        final DateTime end = anchor!;
        // 30 days inclusive: [end-29 .. end]. Negative day rolls into the
        // previous month(s) via DateTime normalization — date-only, DST-safe.
        return DateRange(
          start: DateTime(end.year, end.month, end.day - 29),
          end: end,
        );
      case SummaryPeriodKind.allTime:
        return DateRange(
          start: DateTime(1),
          end: DateTime(9999, 12, 31),
        );
      case SummaryPeriodKind.custom:
        return customRange!;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryPeriodValue &&
          other.kind == kind &&
          other.anchor == anchor &&
          other.customRange == customRange;

  @override
  int get hashCode => Object.hash(kind, anchor, customRange);

  @override
  String toString() =>
      'SummaryPeriodValue($kind, anchor: $anchor, custom: $customRange)';
}
