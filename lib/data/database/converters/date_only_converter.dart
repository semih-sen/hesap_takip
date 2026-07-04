import 'package:drift/drift.dart';

/// Persists a date-only [DateTime] as an ISO `'yyyy-MM-dd'` string.
///
/// PROJECT_PLAN §7: `valueDate` is a date-only concept. Storing it as an ISO
/// date string (rather than a timestamp) means it sorts chronologically, groups
/// by day/month via a simple substring, and carries zero timezone drift. The
/// parsed value is normalized to local midnight (`DateTime(y, m, d)`), so the
/// time component is always zero.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) {
    final List<String> parts = fromDb.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  String toSql(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
