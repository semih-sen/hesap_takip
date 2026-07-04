import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Persists a [Decimal] as its canonical string form.
///
/// PROJECT_PLAN §2/§6: exchange rates must never be stored as REAL/double —
/// float representation would corrupt rate arithmetic. Storing the decimal as
/// text preserves the exact value that was snapshotted on the transaction.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}
