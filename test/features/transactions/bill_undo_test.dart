import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/core/undo/pending_action_queue.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/services/partial_payment_service.dart';

/// Phase 9 §B.7: bill delete and payment reversal flow through the delayed
/// -execution Undo queue — the DB is untouched during the window; on expiry the
/// cascade delete / reversal commits atomically.
const Duration kTestWindow = Duration(milliseconds: 80);
const Duration kAfterWindow = Duration(milliseconds: 220);

void main() {
  late db.AppDatabase database;
  late ProviderContainer container;
  late PendingActionQueue queue;
  late PartialPaymentService service;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer();
    queue = container.read(pendingActionQueueProvider.notifier);
    service = PartialPaymentService(database, const CurrencyService());
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  UndoService makeService() => UndoService(queue, database, window: kTestWindow);

  Future<int> seedWallet() async {
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

  Future<int> seedBillWithPayment(int wallet) async {
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: DateTime(2026, 7, 10),
      categoryIds: const <int>[],
    );
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 400,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: DateTime(2026, 7, 10),
    );
    return parentId;
  }

  test('DeleteBillAction cascades parent + children after the window', () async {
    final int wallet = await seedWallet();
    final int parentId = await seedBillWithPayment(wallet);
    final UndoService undo = makeService();

    final String? id = await undo.enqueue(
      DeleteBillAction(parentId: parentId, label: 'Fatura silindi'),
    );
    expect(id, isNotNull);
    // Untouched during the window.
    expect(await database.transactionDao.getTransactionById(parentId), isNotNull);
    expect((await database.transactionDao.getChildren(parentId)).length, 1);

    await Future<void>.delayed(kAfterWindow);

    expect(await database.transactionDao.getTransactionById(parentId), isNull);
    expect(await database.transactionDao.getChildren(parentId), isEmpty);
  });

  test('ReversePaymentAction reopens the parent and drops the child', () async {
    final int wallet = await seedWallet();
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: DateTime(2026, 7, 10),
      categoryIds: const <int>[],
    );
    // Fully settle so the parent is `completed`, then reverse the only payment.
    final int childId = await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 1000,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: DateTime(2026, 7, 10),
    );
    expect(
      (await database.transactionDao.getTransactionById(parentId))!.status,
      TransactionStatus.completed,
    );

    final UndoService undo = makeService();
    final String? id = await undo.enqueue(
      ReversePaymentAction(
        childId: childId,
        parentId: parentId,
        contribMinor: 1000,
        label: 'Ödeme geri alındı',
      ),
    );
    expect(id, isNotNull);
    // During the window nothing changed.
    expect(await database.transactionDao.getTransactionById(childId), isNotNull);

    await Future<void>.delayed(kAfterWindow);

    // Child gone; parent reopened to pending with settled restored to 0.
    expect(await database.transactionDao.getTransactionById(childId), isNull);
    final db.Transaction parent =
        (await database.transactionDao.getTransactionById(parentId))!;
    expect(parent.status, TransactionStatus.pending);
    expect(parent.settledAmountMinor, 0);
  });
}
