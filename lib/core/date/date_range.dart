import 'package:flutter/foundation.dart';

import 'app_date.dart';

/// An inclusive, date-only span (PROJECT_PLAN §7, §9).
///
/// Both [start] and [end] are normalized to local midnight, so a range never
/// carries a time component and comparisons/grouping stay timezone-drift free.
/// The span is inclusive on both ends: a transaction whose `valueDate` equals
/// [start] or [end] is inside the range.
@immutable
class DateRange {
  /// Builds a range, normalizing both bounds to date-only and ordering them so
  /// [start] is never after [end].
  factory DateRange({required DateTime start, required DateTime end}) {
    final DateTime a = AppDate.dateOnly(start);
    final DateTime b = AppDate.dateOnly(end);
    return a.isAfter(b)
        ? DateRange._(start: b, end: a)
        : DateRange._(start: a, end: b);
  }

  const DateRange._({required this.start, required this.end});

  /// First day in the range (inclusive), date-only.
  final DateTime start;

  /// Last day in the range (inclusive), date-only.
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start … $end)';
}
