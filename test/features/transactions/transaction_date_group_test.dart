import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/presentation/transaction_date_group.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

TransactionListRow rowOn(int id, DateTime date) => TransactionListRow(
  id: id,
  title: 'İşlem $id',
  amountMinor: 1000,
  currencyCode: 'TRY',
  flowDirection: FlowDirection.outflow,
  type: TransactionType.expense,
  status: TransactionStatus.completed,
  walletName: 'Cüzdan',
  valueDate: date,
  accentColorValue: 0xFFFF6B6B,
  accountColorValue: 0xFF5B8DEF,
  baseAmountMinor: 1000,
  baseCurrencyCode: 'TRY',
);

void main() {
  test('groups rows into consecutive same-day buckets, preserving order', () {
    // Pre-sorted newest-first (as the query returns).
    final List<TransactionListRow> rows = <TransactionListRow>[
      rowOn(1, DateTime(2026, 7, 5)),
      rowOn(2, DateTime(2026, 7, 5)),
      rowOn(3, DateTime(2026, 7, 4)),
      rowOn(4, DateTime(2026, 7, 1)),
    ];

    final List<TransactionDateGroup> groups = groupTransactionsByDate(rows);

    expect(groups.map((TransactionDateGroup g) => g.date), <DateTime>[
      DateTime(2026, 7, 5),
      DateTime(2026, 7, 4),
      DateTime(2026, 7, 1),
    ]);
    expect(groups.first.rows.map((TransactionListRow r) => r.id), <int>[1, 2]);
    expect(groups[1].rows.single.id, 3);
  });

  test(
    'a row with a time component still lands under its date-only header',
    () {
      final List<TransactionDateGroup> groups = groupTransactionsByDate(
        <TransactionListRow>[rowOn(1, DateTime(2026, 7, 5, 23, 59))],
      );
      expect(groups.single.date, DateTime(2026, 7, 5));
    },
  );

  group('labels resolve against a fixed clock', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      // The `d MMMM yyyy` fallback formats with DateFormat('…','tr_TR'), which
      // needs the tr date symbols loaded (the app gets these via the Material
      // localizations delegate; a pure test must initialize them explicitly).
      await initializeDateFormatting('tr_TR');
      l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    });

    final DateTime today = DateTime(2026, 7, 5);

    test('today → Bugün', () {
      expect(
        transactionDateGroupLabel(
          DateTime(2026, 7, 5),
          today: today,
          l10n: l10n,
        ),
        'Bugün',
      );
    });

    test('yesterday → Dün (across a month boundary)', () {
      expect(
        transactionDateGroupLabel(
          DateTime(2026, 6, 30),
          today: DateTime(2026, 7, 1),
          l10n: l10n,
        ),
        'Dün',
      );
    });

    test('older → absolute d MMMM yyyy in tr_TR', () {
      expect(
        transactionDateGroupLabel(
          DateTime(2026, 7, 1),
          today: today,
          l10n: l10n,
        ),
        '1 Temmuz 2026',
      );
    });
  });
}
