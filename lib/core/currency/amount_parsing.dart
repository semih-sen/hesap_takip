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
