import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:decimal/decimal.dart';
import 'package:hesap_takip/core/date/app_date.dart';
import 'package:drift/drift.dart' show Batch, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/presentation/widgets/transaction_list_view.dart';
import 'package:hesap_takip/features/transactions/services/summary_period_value.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// PROJECT_PLAN §B.5: prove the list stays bounded and builds smoothly on a
/// large (5,000-row) ledger — the query is windowed (never streamed unbounded)
/// and the sliver list lazily builds only visible rows.

void main() {
  const int kRows = 5000;

  late db.AppDatabase database;

  Future<void> seed() async {
    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int walletId = await database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
    // One batched insert keeps seeding fast; dates spread across days so the
    // list also exercises many sticky date-group headers.
    await database.batch((Batch batch) {
      for (int i = 0; i < kRows; i++) {
        batch.insert(
          database.transactions,
          db.TransactionsCompanion.insert(
            walletId: walletId,
            type: TransactionType.expense,
            flowDirection: FlowDirection.outflow,
            status: TransactionStatus.completed,
            amountMinor: 1000 + i,
            currencyCode: 'TRY',
            exchangeRateToBase: Decimal.one,
            baseAmountMinor: 1000 + i,
            valueDate: DateTime(2026, 1, 1).add(Duration(days: i ~/ 10)),
            note: Value('İşlem $i'),
          ),
        );
      }
    });
  }

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory(logStatements: true));
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'the windowed query stays bounded on 5k rows; load-more grows it',
    () async {
      await seed();
      // Sanity: the ledger really holds 5k rows.
      final int total = await database
          .customSelect('SELECT COUNT(*) AS c FROM transactions')
          .map((row) => row.read<int>('c'))
          .getSingle();
      expect(total, kRows);

      final ProviderContainer container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      container.read(summaryPeriodProvider.notifier).setAllTime();

      container.listen(visibleTransactionsProvider, (_, _) {});
      final listFuture = container.read(transactionListProvider.future);
      listFuture.catchError((e) { print('Future error: $e'); return <TransactionListRow>[]; });
      await listFuture;
      await Future<void>.delayed(Duration.zero);
      
      expect(
        container.read(visibleTransactionsProvider).length,
        kTransactionPageSize,
      );

      // Growing the window pulls exactly one more page.
      container.read(transactionListWindowProvider.notifier).loadMore();
      await container.read(transactionListProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(visibleTransactionsProvider).length,
        kTransactionPageSize * 2,
      );
    },
  );

  testWidgets('list builds and scrolls without exceptions on 5k rows', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(seed);

    // Own the container + dispose it in addTearDown (after the pending-timer
    // check) so the live Drift stream tears down cleanly; drive it with runAsync
    // so it emits before we pump (Phase-3 drift-stream widget-test gotcha).
    final ProviderContainer container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    container.read(summaryPeriodProvider.notifier).setAllTime();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SafeArea(child: TransactionListView())),
        ),
      ),
    );
    await tester.runAsync(() async {
      await container.read(transactionListProvider.future);
    });
    await tester.pump();

    // Debug what is actually rendered
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      print('Widget is still CircularProgressIndicator!');
    }
    if (find.text('Bir hata oluştu.').evaluate().isNotEmpty) {
      print('Widget has an error!');
      final errorStream = container.read(transactionListProvider);
      print('Error is: ${errorStream.error}');
    }

    // The list rendered (not stuck on the loading spinner).
    expect(find.byType(CustomScrollView), findsOneWidget);
    // Lazy slivers build only a viewport's worth of rows — far fewer than 5k,
    // and fewer than one page (a page does not fit in the viewport).
    final int built = tester.widgetList(find.byType(InkWell)).length;
    expect(built, greaterThan(0));
    expect(built, lessThan(kTransactionPageSize));

    // Scrolling does not throw (no unbounded work, headers stay pinned).
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1200),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

