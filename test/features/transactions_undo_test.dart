import 'package:hesap_takip/core/currency/currency_service.dart';
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
import 'package:hesap_takip/data/models/transaction.dart';

/// Short, injected window so the timer path is deterministic.
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

  Future<int> seedWalletTree() async {
    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    return database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
  }

  Future<int> seedTransaction(int walletId) =>
      database.transactionDao.createTransaction(
        db.TransactionsCompanion.insert(
          walletId: walletId,
          type: TransactionType.expense,
          flowDirection: FlowDirection.outflow,
          status: TransactionStatus.completed,
          amountMinor: 1000,
          currencyCode: 'TRY',
          exchangeRateToBase: Decimal.one,
          baseAmountMinor: 1000,
          valueDate: DateTime(2026, 7, 5),
        ),
      );

  Transaction domainTxn(int id, int walletId) => Transaction(
    id: id,
    walletId: walletId,
    type: TransactionType.expense,
    flowDirection: FlowDirection.outflow,
    status: TransactionStatus.completed,
    amount: const Money(minorUnits: 1000, currencyCode: 'TRY'),
    exchangeRateToBase: Decimal.one,
    baseAmountMinor: 1000,
    valueDate: DateTime(2026, 7, 5),
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );

  test('delete hides optimistically with NO DB write during the window, then '
      'commits on expiry', () async {
    final int walletId = await seedWalletTree();
    final int txnId = await seedTransaction(walletId);
    final UndoService undo = makeService();

    final String? id = await undo.enqueue(
      DeleteTransactionAction(
        transaction: domainTxn(txnId, walletId),
        label: 'İşlem silindi',
      ),
    );
    expect(id, isNotNull);
    expect(
      container
          .read(pendingActionQueueProvider)
          .isPendingDeleted(EntityRef(UndoEntityType.transaction, txnId)),
      isTrue,
    );
    // Still in the DB during the window.
    expect(await database.transactionDao.getTransactionById(txnId), isNotNull);

    await Future<void>.delayed(kAfterWindow);

    expect(await database.transactionDao.getTransactionById(txnId), isNull);
    expect(container.read(pendingActionQueueProvider), isEmpty);
  });

  test('undo before expiry performs NO write and clears the overlay', () async {
    final int walletId = await seedWalletTree();
    final int txnId = await seedTransaction(walletId);
    final UndoService undo = makeService();

    final String id = (await undo.enqueue(
      DeleteTransactionAction(
        transaction: domainTxn(txnId, walletId),
        label: 'İşlem silindi',
      ),
    ))!;

    undo.undo(id);
    expect(container.read(pendingActionQueueProvider), isEmpty);

    await Future<void>.delayed(kAfterWindow);
    expect(await database.transactionDao.getTransactionById(txnId), isNotNull);
  });
}

