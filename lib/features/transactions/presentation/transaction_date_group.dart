import 'package:intl/intl.dart';

import '../../../core/date/app_date.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/transactions_providers.dart';

/// A contiguous run of list rows sharing one `valueDate` (date-only), used to
/// build the date-grouped sticky sections (PROJECT_PLAN §B.4).
class TransactionDateGroup {
  const TransactionDateGroup({required this.date, required this.rows});

  /// The shared date-only day of every row in [rows].
  final DateTime date;
  final List<TransactionListRow> rows;
}

/// Groups already-sorted (`valueDate DESC, id DESC`) [rows] into consecutive
/// same-day buckets, preserving order. Because the input is pre-sorted, a single
/// linear pass yields correctly ordered groups without re-sorting.
List<TransactionDateGroup> groupTransactionsByDate(
  List<TransactionListRow> rows,
) {
  final List<TransactionDateGroup> groups = <TransactionDateGroup>[];
  DateTime? currentDay;
  List<TransactionListRow>? bucket;
  for (final TransactionListRow row in rows) {
    final DateTime day = AppDate.dateOnly(row.valueDate);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      bucket = <TransactionListRow>[];
      groups.add(TransactionDateGroup(date: day, rows: bucket));
    }
    bucket!.add(row);
  }
  return groups;
}

/// Localized section header for a group's [date]: "Bugün"/"Dün" resolved against
/// [today] (injected for deterministic tests), else `d MMMM yyyy` in `tr_TR`.
String transactionDateGroupLabel(
  DateTime date, {
  required DateTime today,
  required AppLocalizations l10n,
}) {
  final DateTime day = AppDate.dateOnly(date);
  final DateTime t = AppDate.dateOnly(today);
  // DateTime normalizes day-1 across month/year boundaries; date-only avoids any
  // DST drift a `Duration(days: 1)` subtraction could introduce.
  final DateTime yesterday = DateTime(t.year, t.month, t.day - 1);
  if (day == t) {
    return l10n.dateToday;
  }
  if (day == yesterday) {
    return l10n.dateYesterday;
  }
  return DateFormat('d MMMM yyyy', 'tr_TR').format(day);
}
