import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Persists a [Decimal] as its canonical string form.
///
/// Used for transaction rate snapshots and cached exchange-rate rows so the
/// original decimal value is not forced through a binary floating point type.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}
