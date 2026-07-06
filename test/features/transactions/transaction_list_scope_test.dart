import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:decimal/decimal.dart';
import 'package:hesap_takip/core/date/app_date.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/money.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/core/undo/pending_action_queue.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/transaction.dart';
import 'package:hesap_takip/data/models/transaction_filter.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';
import 'package:hesap_takip/features/transactions/services/summary_period_value.dart';

void main() {
  group('TransactionListFilter notifier (List scope)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('initial() is unnarrowed and inactive', () {
      final TransactionFilter f = container.read(transactionListFilterProvider);
      expect(f, TransactionFilter.initial());
      expect(f.isActive, isFalse);
      expect(f.walletIds, isEmpty); // empty = ALL
    });

    test('setters narrow the filter and mark it active', () {
      final TransactionListFilter notifier = container.read(
        transactionListFilterProvider.notifier,
      );
      notifier.setWallets(<int>{1, 2});
      notifier.setType(TransactionType.income);
      notifier.setSearch('market');
      notifier.setDateRange(
        DateRange(start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 31)),
      );

      final TransactionFilter f = container.read(transactionListFilterProvider);
      expect(f.walletIds, <int>{1, 2});
      expect(f.type, TransactionType.income);
      expect(f.search, 'market');
      expect(f.range, isNotNull);
      expect(f.isActive, isTrue);
    });

    test('setDateRange(null) clears the range', () {
      final TransactionListFilter notifier = container.read(
        transactionListFilterProvider.notifier,
      );
      notifier.setDateRange(
        DateRange(start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 2)),
      );
      notifier.setDateRange(null);
      expect(container.read(transactionListFilterProvider).range, isNull);
    });

    test('reset() restores the unnarrowed default', () {
      final TransactionListFilter notifier = container.read(
        transactionListFilterProvider.notifier,
      );
      notifier.setWallets(<int>{5});
      notifier.setStatus(TransactionStatus.pending);
      notifier.reset();

      expect(
        container.read(transactionListFilterProvider),
        TransactionFilter.initial(),
      );
    });
  });

  group('TransactionListWindow (pagination)', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('loadMore grows the window; a filter change resets it to 1', () {
      // Keep the window provider alive so it recomputes on filter changes.
      container.listen(
        transactionListWindowProvider,
        (_, _) {},
        fireImmediately: true,
      );
      expect(container.read(transactionListWindowProvider), 1);

      container.read(transactionListWindowProvider.notifier).loadMore();
      container.read(transactionListWindowProvider.notifier).loadMore();
      expect(container.read(transactionListWindowProvider), 3);

      // Changing the filter re-runs the window's build → resets to 1.
      container
          .read(transactionListFilterProvider.notifier)
          .setType(TransactionType.expense);
      expect(container.read(transactionListWindowProvider), 1);
    });
  });

  group('Undo overlay survives the filtered/paginated pipeline', () {
    late db.AppDatabase database;
    late ProviderContainer container;

    setUp(() {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      container.read(summaryPeriodProvider.notifier).setAllTime();
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    Future<int> seed() async {
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
      return database.transactionDao.createTransaction(
        db.TransactionsCompanion.insert(
          walletId: walletId,
          type: TransactionType.expense,
          flowDirection: FlowDirection.outflow,
          status: TransactionStatus.completed,
          amountMinor: 1000,
          currencyCode: 'TRY',
          exchangeRateToBase: Decimal.one,
          baseAmountMinor: 1000,
          valueDate: AppDate.today(),
        ),
      );
    }

    Transaction domain(int id, int walletId) => Transaction(
      id: id,
      walletId: walletId,
      type: TransactionType.expense,
      flowDirection: FlowDirection.outflow,
      status: TransactionStatus.completed,
      amount: const Money(minorUnits: 1000, currencyCode: 'TRY'),
      exchangeRateToBase: Decimal.one,
      baseAmountMinor: 1000,
      valueDate: AppDate.today(),
      createdAt: AppDate.today(),
      updatedAt: AppDate.today(),
    );

    test('a queued delete is hidden then returns on undo', () async {
      final int txnId = await seed();
      final int walletId = (await database.transactionDao.getTransactionById(
        txnId,
      ))!.walletId;

      // Keep the overlaid list (and, transitively, the DB stream) alive, then
      // wait for the first stream emission.
      container.listen(visibleTransactionsProvider, (_, _) {});
      await container.read(transactionListProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(visibleTransactionsProvider).length, 1);

      // Queue a delete through the real UndoService (long window — no commit).
      final PendingActionQueue queue = container.read(
        pendingActionQueueProvider.notifier,
      );
      final UndoService undo = UndoService(
        queue,
        database,
        window: const Duration(seconds: 30),
      );
      final String pendingId = (await undo.enqueue(
        DeleteTransactionAction(
          transaction: domain(txnId, walletId),
          label: 'İşlem silindi',
        ),
      ))!;

      // Optimistically hidden from the filtered/grouped pipeline...
      expect(container.read(visibleTransactionsProvider), isEmpty);
      // ...but never committed to the DB during the window.
      expect(
        await database.transactionDao.getTransactionById(txnId),
        isNotNull,
      );

      // Undo → the row reappears.
      undo.undo(pendingId);
      expect(container.read(visibleTransactionsProvider).length, 1);
    });
  });
}

