import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Persists a [Decimal] as its canonical string form.
///
/// Used for legacy transaction rate snapshots that still preserve their
/// original decimal text. Cached exchange-rate rows use SQLite REAL/double.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}
