import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/money.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/core/undo/pending_action_queue.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/core/undo/undoable_action.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/wallet.dart';

/// Short, injected window so the timer path is deterministic without waiting the
/// production 4.5s.
const Duration kTestWindow = Duration(milliseconds: 80);
const Duration kAfterWindow = Duration(milliseconds: 220);

void main() {
  late db.AppDatabase database;
  late ProviderContainer container;
  late PendingActionQueue queue;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer();
    queue = container.read(pendingActionQueueProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  UndoService makeService() =>
      UndoService(queue, database, window: kTestWindow);

  Future<int> seedAccount() => database.accountDao.createAccount(
    db.AccountsCompanion.insert(
      name: 'Hesap',
      type: AccountType.bank,
      colorValue: 0xFF000000,
      iconCodePoint: 0xE000,
    ),
  );

  Future<int> seedWallet(int accountId, {String code = 'TRY'}) =>
      database.walletDao.createWallet(
        db.WalletsCompanion.insert(
          accountId: accountId,
          name: 'Cüzdan',
          currencyCode: code,
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );

  Wallet domainWallet(int id, int accountId, {String name = 'Cüzdan'}) =>
      Wallet(
        id: id,
        accountId: accountId,
        name: name,
        initialBalance: const Money(minorUnits: 0, currencyCode: 'TRY'),
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
        isArchived: false,
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('enqueue leaves the DB untouched during the window, commits on '
      'expiry exactly once', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId);
    final UndoService undo = makeService();

    final String? id = await undo.enqueue(
      DeleteWalletAction(
        wallet: domainWallet(walletId, accountId),
        label: 'silindi',
      ),
    );
    expect(id, isNotNull);
    // Optimistically hidden, but the row still exists (no write yet).
    expect(
      container
          .read(pendingActionQueueProvider)
          .isPendingDeleted(EntityRef(UndoEntityType.wallet, walletId)),
      isTrue,
    );
    expect(await database.walletDao.getWalletById(walletId), isNotNull);

    await Future<void>.delayed(kAfterWindow);

    // Committed and dequeued.
    expect(await database.walletDao.getWalletById(walletId), isNull);
    expect(container.read(pendingActionQueueProvider), isEmpty);
  });

  test('undo before expiry performs NO write and clears the overlay', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId);
    final UndoService undo = makeService();

    final String id = (await undo.enqueue(
      DeleteWalletAction(
        wallet: domainWallet(walletId, accountId),
        label: 'silindi',
      ),
    ))!;

    undo.undo(id);
    expect(container.read(pendingActionQueueProvider), isEmpty);

    // Even after the window would have elapsed, nothing was written.
    await Future<void>.delayed(kAfterWindow);
    expect(await database.walletDao.getWalletById(walletId), isNotNull);
  });

  test('enqueuing a second action for the same target commits the prior '
      'first (supersede)', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId);
    final UndoService undo = makeService();
    final Wallet base = domainWallet(walletId, accountId);

    await undo.enqueue(
      UpdateWalletAction(
        wallet: base.copyWith(name: 'A'),
        label: 'a',
      ),
    );
    await undo.enqueue(
      UpdateWalletAction(
        wallet: base.copyWith(name: 'B'),
        label: 'b',
      ),
    );

    // The prior (name 'A') was committed synchronously during the 2nd enqueue.
    expect((await database.walletDao.getWalletById(walletId))!.name, 'A');
    expect(container.read(pendingActionQueueProvider).length, 1);

    await Future<void>.delayed(kAfterWindow);
    // The superseding action (name 'B') committed on expiry.
    expect((await database.walletDao.getWalletById(walletId))!.name, 'B');
    expect(container.read(pendingActionQueueProvider), isEmpty);
  });

  test('flushAllNow commits every pending entry immediately', () async {
    final int accountId = await seedAccount();
    final int walletA = await seedWallet(accountId);
    final int walletB = await seedWallet(accountId);
    final UndoService undo = makeService();

    await undo.enqueue(
      DeleteWalletAction(wallet: domainWallet(walletA, accountId), label: 'a'),
    );
    await undo.enqueue(
      DeleteWalletAction(wallet: domainWallet(walletB, accountId), label: 'b'),
    );
    expect(container.read(pendingActionQueueProvider).length, 2);

    await undo.flushAllNow();

    expect(await database.walletDao.getWalletById(walletA), isNull);
    expect(await database.walletDao.getWalletById(walletB), isNull);
    expect(container.read(pendingActionQueueProvider), isEmpty);
  });

  test('canCommit rejects a wallet with transactions at enqueue: nothing is '
      'queued or hidden', () async {
    final int accountId = await seedAccount();
    final int walletId = await seedWallet(accountId);
    await database.transactionDao.createTransaction(
      db.TransactionsCompanion.insert(
        walletId: walletId,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 1000,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 1000,
        valueDate: DateTime(2026, 7, 4),
      ),
    );
    final UndoService undo = makeService();

    final String? id = await undo.enqueue(
      DeleteWalletAction(
        wallet: domainWallet(walletId, accountId),
        label: 'silindi',
      ),
    );

    expect(id, isNull); // rejected
    expect(container.read(pendingActionQueueProvider), isEmpty);
    expect(
      container
          .read(pendingActionQueueProvider)
          .isPendingDeleted(EntityRef(UndoEntityType.wallet, walletId)),
      isFalse,
    );
    expect(await database.walletDao.getWalletById(walletId), isNotNull);
  });
}
