/// Date-only helpers (PROJECT_PLAN §7).
///
/// `valueDate` and every recurring date are date-only concepts: a [DateTime]
/// normalized to local midnight (`DateTime(y, m, d)`), never carrying a time
/// component. Persisting `DateTime.now()` (with time) into such a column is a
/// bug — always route through here.
abstract final class AppDate {
  AppDate._();

  /// Today, normalized to local midnight (time components stripped).
  static DateTime today() => dateOnly(DateTime.now());

  /// Strips the time-of-day from [dt], returning local midnight of the same
  /// calendar day. Idempotent.
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Number of days in [month] of [year] (1-based month), leap-year aware for
  /// February. Uses the `DateTime(year, month + 1, 0)` roll-over trick: day 0 of
  /// the next month is the last day of this one.
  static int lastDayOfMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Adds [months] calendar months to [date], then clamps the day to the target
  /// month's last valid day. The day is DERIVED FRESH from [dayOverride] (falling
  /// back to `date.day`) every call — never from a previously-clamped result —
  /// so a monthly-on-the-31st rule lands on Feb 28/29 then snaps back to Mar 31,
  /// rather than drifting to the 28th permanently (PROJECT_PLAN §8.4).
  ///
  /// [months] may be negative. The returned value is date-only (local midnight).
  static DateTime addMonthsClamped(
    DateTime date,
    int months, {
    int? dayOverride,
  }) {
    // Absolute month index from year 0 (always positive for real dates), so
    // `~/` and `%` behave for negative [months] too — Dart's `%` on a small
    // negative dividend would otherwise land on the wrong year.
    final int monthIndex = date.year * 12 + (date.month - 1) + months;
    final int targetYear = monthIndex ~/ 12;
    final int targetMonth = (monthIndex % 12) + 1;
    final int lastDay = lastDayOfMonth(targetYear, targetMonth);
    final int desiredDay = dayOverride ?? date.day;
    final int day = desiredDay < lastDay ? desiredDay : lastDay;
    return DateTime(targetYear, targetMonth, day);
  }
}
