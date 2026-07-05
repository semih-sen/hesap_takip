import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/presentation/widgets/transaction_list_item.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Golden tests locking the bespoke row's layout for every variant that is
/// representable today (PROJECT_PLAN §B.2). Uses the app's real dark theme (so
/// `AppSemanticColors.dark` is present) and a fixed `valueDate` so the label is
/// a stable absolute date ("5 Tem 2026"), never a relative "Bugün".
void main() {
  // A fixed, non-relative date so the golden never depends on the clock.
  final DateTime fixedDate = DateTime(2026, 7, 5);

  TransactionListRow row({
    required String? title,
    required TransactionType type,
    required FlowDirection flow,
    int amountMinor = 125000,
    TransactionStatus status = TransactionStatus.completed,
    String? note,
    List<CategoryChipData> categories = const <CategoryChipData>[],
    bool isPending = false,
    bool isOverdue = false,
    String? counterWalletName,
    bool isRecurring = false,
    int accountColorValue = 0xFF5B8DEF,
  }) {
    return TransactionListRow(
      id: 1,
      title: title,
      amountMinor: amountMinor,
      currencyCode: 'TRY',
      flowDirection: flow,
      type: type,
      status: status,
      walletName: 'Vadesiz',
      valueDate: fixedDate,
      accentColorValue: categories.isEmpty
          ? 0xFFFF6B6B
          : categories.first.colorValue,
      accountColorValue: accountColorValue,
      note: note,
      categories: categories,
      isPending: isPending,
      isOverdue: isOverdue,
      counterWalletName: counterWalletName,
      isRecurring: isRecurring,
    );
  }

  Future<void> pumpRow(WidgetTester tester, TransactionListRow r) async {
    await tester.binding.setSurfaceSize(const Size(420, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TransactionListItem(row: r),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('plain single-category expense', (WidgetTester tester) async {
    await pumpRow(
      tester,
      row(
        title: 'Market',
        type: TransactionType.expense,
        flow: FlowDirection.outflow,
        note: 'Haftalık alışveriş',
        categories: const <CategoryChipData>[
          CategoryChipData(id: 1, name: 'Market', colorValue: 0xFFFF6B6B),
        ],
      ),
    );
    await expectLater(
      find.byType(TransactionListItem),
      matchesGoldenFile('goldens/list_item_single_category.png'),
    );
  });

  testWidgets('multi-category chips with overflow', (
    WidgetTester tester,
  ) async {
    await pumpRow(
      tester,
      row(
        title: 'Maaş',
        type: TransactionType.income,
        flow: FlowDirection.inflow,
        categories: const <CategoryChipData>[
          CategoryChipData(id: 1, name: 'Maaş', colorValue: 0xFF3DD68C),
          CategoryChipData(id: 2, name: 'Prim', colorValue: 0xFF5B8DEF),
          CategoryChipData(id: 3, name: 'İkramiye', colorValue: 0xFFF5A623),
          CategoryChipData(id: 4, name: 'Diğer', colorValue: 0xFF9B59B6),
        ],
      ),
    );
    await expectLater(
      find.byType(TransactionListItem),
      matchesGoldenFile('goldens/list_item_multi_category.png'),
    );
  });

  testWidgets('pending overdue borç (fixture)', (WidgetTester tester) async {
    await pumpRow(
      tester,
      row(
        title: 'Kira',
        type: TransactionType.expense,
        flow: FlowDirection.outflow,
        amountMinor: 1000000,
        status: TransactionStatus.pending,
        isPending: true,
        isOverdue: true,
      ),
    );
    await expectLater(
      find.byType(TransactionListItem),
      matchesGoldenFile('goldens/list_item_pending.png'),
    );
  });

  testWidgets('recurring chip (fixture)', (WidgetTester tester) async {
    await pumpRow(
      tester,
      row(
        title: 'Netflix',
        type: TransactionType.expense,
        flow: FlowDirection.outflow,
        isRecurring: true,
      ),
    );
    await expectLater(
      find.byType(TransactionListItem),
      matchesGoldenFile('goldens/list_item_recurring.png'),
    );
  });

  testWidgets('pending expense shows the Borç chip; overdue adds Gecikmiş', (
    WidgetTester tester,
  ) async {
    await pumpRow(
      tester,
      row(
        title: 'Kira',
        type: TransactionType.expense,
        flow: FlowDirection.outflow,
        status: TransactionStatus.pending,
        isPending: true,
        isOverdue: true,
      ),
    );
    expect(find.text('Borç'), findsOneWidget);
    expect(find.text('Gecikmiş'), findsOneWidget);
    expect(find.text('Alacak'), findsNothing);
  });

  testWidgets('pending income shows the Alacak chip; not-overdue hides Gecikmiş', (
    WidgetTester tester,
  ) async {
    await pumpRow(
      tester,
      row(
        title: 'Maaş',
        type: TransactionType.income,
        flow: FlowDirection.inflow,
        status: TransactionStatus.pending,
        isPending: true,
      ),
    );
    expect(find.text('Alacak'), findsOneWidget);
    expect(find.text('Gecikmiş'), findsNothing);
  });

  testWidgets('transfer counter-wallet (fixture)', (WidgetTester tester) async {
    await pumpRow(
      tester,
      row(
        title: null,
        type: TransactionType.transfer,
        flow: FlowDirection.outflow,
        counterWalletName: 'Birikim',
      ),
    );
    await expectLater(
      find.byType(TransactionListItem),
      matchesGoldenFile('goldens/list_item_transfer.png'),
    );
  });
}
