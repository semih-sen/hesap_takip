import 'package:decimal/decimal.dart';

/// Parses a monetary amount typed with the Turkish convention: `.` groups
/// thousands and `,` is the decimal separator (e.g. `1.234,56`).
///
/// Shared by every money-entry form (wallet initial balance, transaction
/// amount, per-category split) so the parsing rule lives in exactly one place.
///
/// Returns [Decimal.zero] for empty/whitespace input and `null` when the text
/// is not a valid number (so validators can reject it).
Decimal? parseTurkishAmount(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return Decimal.zero;
  }
  final String normalized = trimmed
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return Decimal.tryParse(normalized);
}

/// Parses exchange-rate values where either `,` or `.` may be the decimal
/// separator. If both appear, the last separator is treated as decimal and the
/// other as a thousands separator.
Decimal? parseExchangeRateAmount(String raw) {
  final String compact = raw.trim().replaceAll(' ', '');
  if (compact.isEmpty) {
    return Decimal.zero;
  }

  final int lastComma = compact.lastIndexOf(',');
  final int lastDot = compact.lastIndexOf('.');
  if (lastComma == -1 && lastDot == -1) {
    return Decimal.tryParse(compact);
  }

  final String decimalSeparator = lastComma > lastDot ? ',' : '.';
  final String groupingSeparator = decimalSeparator == ',' ? '.' : ',';
  final String normalized = compact
      .replaceAll(groupingSeparator, '')
      .replaceAll(decimalSeparator, '.');
  return Decimal.tryParse(normalized);
}
