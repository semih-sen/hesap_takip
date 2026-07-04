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
}
