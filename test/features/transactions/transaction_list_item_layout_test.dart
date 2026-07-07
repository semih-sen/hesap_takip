import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/data/database/seed.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/presentation/widgets/transaction_list_item.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Non-golden layout guarantees for the bespoke row (Part A):
///  1. the left stripe paints the OWNING ACCOUNT color, not the accent/tint.
///  2. every Row-3 variant renders at the exact same height.
void main() {
  final DateTime fixedDate = DateTime(2026, 7, 5);

  TransactionListRow row({
    String? title = 'İşlem',
    TransactionType type = TransactionType.expense,
    FlowDirection flow = FlowDirection.outflow,
    List<CategoryChipData> categories = const <CategoryChipData>[],
    bool isPending = false,
    bool isOverdue = false,
    String? counterWalletName,
    bool isRecurring = false,
    int accentColorValue = 0xFFFF6B6B,
    int accountColorValue = 0xFF5B8DEF,
  }) {
    return TransactionListRow(
      id: 1,
      title: title,
      amountMinor: 125000,
      currencyCode: 'TRY',
      flowDirection: flow,
      type: type,
      status: isPending
          ? TransactionStatus.pending
          : TransactionStatus.completed,
      walletName: 'Vadesiz',
      valueDate: fixedDate,
      accentColorValue: accentColorValue,
      accountColorValue: accountColorValue,
      categories: categories,
      isPending: isPending,
      isOverdue: isOverdue,
      counterWalletName: counterWalletName,
      isRecurring: isRecurring,
      baseAmountMinor: 125000,
      baseCurrencyCode: 'TRY',
    );
  }

  Widget wrap(List<TransactionListRow> rows, {double width = 380}) {
    final currency = CurrencyService(
      kDefaultCurrencies
          .map(
            (c) => Currency(
              code: c.code,
              symbol: c.symbol,
              minorDigits: c.minorDigits,
              symbolOnLeft: c.symbolOnLeft,
            ),
          )
          .toList(),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('tr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('tr')],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final TransactionListRow r in rows)
                  TransactionListItem(
                    key: ValueKey<int>(r.id),
                    row: r,
                    currency: currency,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('stripe uses the account color, independent of the accent/tint', (
    WidgetTester tester,
  ) async {
    const int accountColor = 0xFF00A000;
    const int accentColor = 0xFFFF6B6B;
    await tester.pumpWidget(
      wrap(<TransactionListRow>[
        row(accentColorValue: accentColor, accountColorValue: accountColor),
      ]),
    );
    await tester.pumpAndSettle();

    // The 5px stripe is a Container whose `color` is the account color.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Container && w.color == const Color(accountColor),
      ),
      findsOneWidget,
    );
    // Nothing paints the accent as a solid stripe color (it only tints via a
    // BoxDecoration with alpha), so a solid Container of the accent must NOT
    // exist.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Container && w.color == const Color(accentColor),
      ),
      findsNothing,
    );
  });

  testWidgets('every Row-3 variant renders at identical height', (
    WidgetTester tester,
  ) async {
    final List<TransactionListRow> rows = <TransactionListRow>[
      // 0: no Row-3 content at all (no categories, not pending/transfer/recurring).
      row(),
      // 1: three category chips.
      row(
        categories: const <CategoryChipData>[
          CategoryChipData(id: 1, name: 'Market', colorValue: 0xFFFF6B6B),
          CategoryChipData(id: 2, name: 'Gıda', colorValue: 0xFF3DD68C),
          CategoryChipData(id: 3, name: 'Ev', colorValue: 0xFF5B8DEF),
        ],
      ),
      // 2: pending overdue borç (badge now in Row 1; Row 3 empty).
      row(isPending: true, isOverdue: true),
      // 3: transfer counter-wallet.
      row(type: TransactionType.transfer, counterWalletName: 'Birikim'),
      // 4: recurring chip.
      row(isRecurring: true),
      // 5: pending WITH categories — badge in Row 1 AND chips in Row 3 (§D.2).
      row(
        isPending: true,
        isOverdue: true,
        categories: const <CategoryChipData>[
          CategoryChipData(id: 9, name: 'Ev', colorValue: 0xFFF5A623),
        ],
      ),
    ];
    // Distinct ids so ValueKey is unique.
    final List<TransactionListRow> keyed = <TransactionListRow>[
      for (int i = 0; i < rows.length; i++)
        TransactionListRow(
          id: i + 1,
          title: rows[i].title,
          amountMinor: rows[i].amountMinor,
          currencyCode: rows[i].currencyCode,
          flowDirection: rows[i].flowDirection,
          type: rows[i].type,
          status: rows[i].status,
          walletName: rows[i].walletName,
          valueDate: rows[i].valueDate,
          accentColorValue: rows[i].accentColorValue,
          accountColorValue: rows[i].accountColorValue,
          categories: rows[i].categories,
          isPending: rows[i].isPending,
          isOverdue: rows[i].isOverdue,
          counterWalletName: rows[i].counterWalletName,
          isRecurring: rows[i].isRecurring,
          baseAmountMinor: rows[i].baseAmountMinor,
          baseCurrencyCode: rows[i].baseCurrencyCode,
        ),
    ];

    await tester.pumpWidget(wrap(keyed));
    await tester.pumpAndSettle();

    final double baseline = tester
        .getSize(find.byType(TransactionListItem).at(0))
        .height;
    for (int i = 1; i < keyed.length; i++) {
      expect(
        tester.getSize(find.byType(TransactionListItem).at(i)).height,
        baseline,
        reason: 'row $i height differs from the empty-Row-3 baseline',
      );
    }
  });

  testWidgets(
    'a pending row shows the badge in Row 1, keeps Row-3 for categories, and '
    'no longer repeats the due date (§D.2)',
    (WidgetTester tester) async {
      final TransactionListRow pending = row(
        isPending: true,
        isOverdue: true,
        categories: const <CategoryChipData>[
          CategoryChipData(id: 1, name: 'Kira', colorValue: 0xFFF5A623),
        ],
      );
      await tester.pumpWidget(wrap(<TransactionListRow>[pending]));
      await tester.pumpAndSettle();

      // Due debt badge + its overdue icon are present; category chip shows in Row 3.
      expect(find.text('Günü gelen Borç'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Kira'), findsOneWidget);
      // The old "Vade: …" due-date line is gone (Row 2 already shows the date).
      // (Guard against matching the wallet name "Vadesiz" — check the colon.)
      expect(find.textContaining('Vade:'), findsNothing);

      // Same fixed height as a plain completed row.
      final double pendingHeight = tester
          .getSize(find.byType(TransactionListItem))
          .height;
      await tester.pumpWidget(wrap(<TransactionListRow>[row()]));
      await tester.pumpAndSettle();
      final double plainHeight = tester
          .getSize(find.byType(TransactionListItem))
          .height;
      expect(pendingHeight, plainHeight);
    },
  );
}
