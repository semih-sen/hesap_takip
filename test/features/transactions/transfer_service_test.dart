import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/seed.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/core/undo/pending_action_queue.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/core/undo/undoable_action.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';
import 'package:hesap_takip/features/transactions/services/transfer_service.dart';

/// Phase 8 §B.8: two-leg transfers move balances correctly (same- and
/// cross-currency), are atomic on every path (0-or-2 legs), stay invisible to
/// the summary flow rows, and undo/flush both legs together.
void main() {
  late AppDatabase db;
  late TransferService service;
  late DriftTransactionRepository repo;

  late CurrencyService currency;
  final DateTime date = DateTime(2026, 7, 10);
  final DateRange july = DateRange(
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 31),
  );
  final DateTime endOfJuly = DateTime(2026, 7, 31);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    currency = CurrencyService(
      const [
  Currency(code: 'TRY', symbol: '₺', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'USD', symbol: '\$', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'EUR', symbol: '€', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),

],
    );
    service = TransferService(db, currency);
    repo = DriftTransactionRepository(db, currency);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedAccount() => db.accountDao.createAccount(
    AccountsCompanion.insert(
      name: 'Hesap',
      type: AccountType.bank,
      colorValue: 0xFF000000,
      iconCodePoint: 0xE000,
    ),
  );

  Future<int> seedWallet(int account, {String code = 'TRY'}) =>
      db.walletDao.createWallet(
        WalletsCompanion.insert(
          accountId: account,
          name: 'Cüzdan-$code',
          currencyCode: code,
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );

  Future<int> balance(int walletId) =>
      db.transactionDao.watchWalletBalanceMinor(walletId).first;

  test('same-currency transfer moves both balances; delete removes both legs',
      () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);

    final String groupId = await service.createTransfer(
      fromWalletId: w1,
      toWalletId: w2,
      fromAmountMinor: 5000,
      toAmountMinor: 5000,
      rate: 1.0,
      valueDate: date,
    );

    expect(await balance(w1), -5000);
    expect(await balance(w2), 5000);
    expect((await db.transactionDao.getTransferLegs(groupId)).length, 2);

    await service.deleteTransfer(groupId);
    expect((await db.transactionDao.getTransferLegs(groupId)), isEmpty);
    expect(await balance(w1), 0);
    expect(await balance(w2), 0);
  });

  test('cross-currency transfer: converted destination + own base snapshots',
      () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account); // TRY (base)
    final int w3 = await seedWallet(account, code: 'USD');

    // 100.00 TRY → USD at 0.03 → 3.00 USD (300 minor).
    final Decimal rate = Decimal.parse('0.03');
    final int toMinor = currency.convertMinor(
      amountMinor: 10000,
      fromCode: 'TRY',
      toCode: 'USD',
      rate: rate.toDouble(),
    );
    expect(toMinor, 300);

    final String groupId = await service.createTransfer(
      fromWalletId: w1,
      toWalletId: w3,
      fromAmountMinor: 10000,
      toAmountMinor: toMinor,
      rate: rate.toDouble(),
      valueDate: date,
    );

    // Balances move in each wallet's own currency.
    expect(await balance(w1), -10000); // TRY
    expect(await balance(w3), 300); // USD

    final List<Transaction> legs = await db.transactionDao.getTransferLegs(
      groupId,
    );
    final Transaction out =
        legs.firstWhere((Transaction l) => l.flowDirection == FlowDirection.outflow);
    final Transaction into =
        legs.firstWhere((Transaction l) => l.flowDirection == FlowDirection.inflow);
    expect(out.amountMinor, 10000);
    expect(out.currencyCode, 'TRY');
    expect(into.amountMinor, 300);
    expect(into.currencyCode, 'USD');
    // Each leg carries its OWN base snapshot (Flag B-3): out is already base
    // (10000 TRY); in converts USD→base at fallback 1.0 → 300. They differ.
    expect(out.baseAmountMinor, 10000);
    expect(into.baseAmountMinor, 300);
  });

  test('transfers stay out of summary flows; move Row-1 cash per Decision 2A',
      () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);
    // A real income so the flow rows are non-zero.
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: w1,
        type: TransactionType.income,
        flowDirection: FlowDirection.inflow,
        status: TransactionStatus.completed,
        amountMinor: 30000,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 30000,
        valueDate: DateTime(2026, 7, 5),
      ),
    );

    Future<SummaryData> summaryAll() => repo
        .watchSummary(walletIds: const <int>{}, period: july, today: endOfJuly)
        .first;
    Future<SummaryData> summaryW2() => repo
        .watchSummary(walletIds: <int>{w2}, period: july, today: endOfJuly)
        .first;

    final SummaryData allBefore = await summaryAll();
    final SummaryData w2Before = await summaryW2();

    await service.createTransfer(
      fromWalletId: w1,
      toWalletId: w2,
      fromAmountMinor: 5000,
      toAmountMinor: 5000,
      rate: 1.0,
      valueDate: date,
    );

    final SummaryData allAfter = await summaryAll();
    // Flow rows unaffected by the transfer (B-2).
    expect(allAfter.incomeTotalMinor, allBefore.incomeTotalMinor);
    expect(allAfter.expenseTotalMinor, allBefore.expenseTotalMinor);
    // Both legs in scope → cash nets to zero.
    expect(allAfter.currentCashMinor, allBefore.currentCashMinor);

    final SummaryData w2After = await summaryW2();
    // Only the in-leg is in scope → W2 cash rises by the transferred amount (2A).
    expect(w2After.incomeTotalMinor, w2Before.incomeTotalMinor); // still 0
    expect(w2After.currentCashMinor - w2Before.currentCashMinor, 5000);
  });

  test('undo keeps both legs; flush commits both', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);
    final String groupId = await service.createTransfer(
      fromWalletId: w1,
      toWalletId: w2,
      fromAmountMinor: 5000,
      toAmountMinor: 5000,
      rate: 1.0,
      valueDate: date,
    );
    final List<Transaction> legs =
        await db.transactionDao.getTransferLegs(groupId);
    final List<int> legIds = <int>[for (final Transaction l in legs) l.id];

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final PendingActionQueue queue = container.read(
      pendingActionQueueProvider.notifier,
    );
    final UndoService undo = UndoService(
      queue,
      db,
      window: const Duration(seconds: 30),
    );

    final String pendingId = (await undo.enqueue(
      DeleteTransferAction(
        transferGroupId: groupId,
        legTransactionIds: legIds,
        label: 'Transfer silindi',
      ),
    ))!;

    // The overlay hides BOTH legs during the window...
    final List<PendingEntry> entries = container.read(pendingActionQueueProvider);
    expect(
      entries.isPendingDeleted(EntityRef(UndoEntityType.transaction, legIds[0])),
      isTrue,
    );
    expect(
      entries.isPendingDeleted(EntityRef(UndoEntityType.transaction, legIds[1])),
      isTrue,
    );
    // ...but nothing is committed yet.
    expect((await db.transactionDao.getTransferLegs(groupId)).length, 2);

    // Undo → both legs survive.
    undo.undo(pendingId);
    expect((await db.transactionDao.getTransferLegs(groupId)).length, 2);

    // Re-enqueue then flush (app paused) → both legs committed away.
    await undo.enqueue(
      DeleteTransferAction(
        transferGroupId: groupId,
        legTransactionIds: legIds,
        label: 'Transfer silindi',
      ),
    );
    await undo.flushAllNow();
    expect((await db.transactionDao.getTransferLegs(groupId)), isEmpty);
  });

  group('auto-append transfer details to notes', () {
    test('same-account transfer: note includes wallet names', () async {
      final int account = await seedAccount();
      final int w1 = await seedWallet(account);
      final int w2 = await seedWallet(account);

      final String groupId = await service.createTransfer(
        fromWalletId: w1,
        toWalletId: w2,
        fromAmountMinor: 5000,
        toAmountMinor: 5000,
        rate: 1.0,
        valueDate: date,
      );

      final List<Transaction> legs =
          await db.transactionDao.getTransferLegs(groupId);
      // Both legs should have the same note with transfer detail.
      for (final Transaction leg in legs) {
        expect(leg.note, contains('Transfer:'));
        expect(leg.note, contains('Cüzdan-TRY'));
        expect(leg.note, contains('->'));
      }
    });

    test('cross-account transfer: note includes account/wallet names',
        () async {
      final int account1 = await db.accountDao.createAccount(
        AccountsCompanion.insert(
          name: 'Banka1',
          type: AccountType.bank,
          colorValue: 0xFF000000,
          iconCodePoint: 0xE000,
        ),
      );
      final int account2 = await db.accountDao.createAccount(
        AccountsCompanion.insert(
          name: 'Banka2',
          type: AccountType.bank,
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );
      final int w1 = await db.walletDao.createWallet(
        WalletsCompanion.insert(
          accountId: account1,
          name: 'TL Hesap',
          currencyCode: 'TRY',
          colorValue: 0xFF222222,
          iconCodePoint: 0xE002,
        ),
      );
      final int w2 = await db.walletDao.createWallet(
        WalletsCompanion.insert(
          accountId: account2,
          name: 'Dolar Hesap',
          currencyCode: 'USD',
          colorValue: 0xFF333333,
          iconCodePoint: 0xE003,
        ),
      );

      final String groupId = await service.createTransfer(
        fromWalletId: w1,
        toWalletId: w2,
        fromAmountMinor: 10000,
        toAmountMinor: 300,
        rate: 0.03,
        valueDate: date,
      );

      final List<Transaction> legs =
          await db.transactionDao.getTransferLegs(groupId);
      for (final Transaction leg in legs) {
        expect(leg.note, contains('Transfer: Banka1/TL Hesap -> Banka2/Dolar Hesap'));
      }
    });

    test('null note: transfer detail becomes the sole note', () async {
      final int account = await seedAccount();
      final int w1 = await seedWallet(account);
      final int w2 = await seedWallet(account);

      final String groupId = await service.createTransfer(
        fromWalletId: w1,
        toWalletId: w2,
        fromAmountMinor: 1000,
        toAmountMinor: 1000,
        rate: 1.0,
        valueDate: date,
        note: null,
      );

      final List<Transaction> legs =
          await db.transactionDao.getTransferLegs(groupId);
      for (final Transaction leg in legs) {
        // Note should be exactly the transfer detail, no leading newline.
        expect(leg.note, isNotNull);
        expect(leg.note, startsWith('Transfer:'));
        expect(leg.note!.contains('\n'), isFalse);
      }
    });

    test('user-provided note: transfer detail appended after newline',
        () async {
      final int account = await seedAccount();
      final int w1 = await seedWallet(account);
      final int w2 = await seedWallet(account);

      final String groupId = await service.createTransfer(
        fromWalletId: w1,
        toWalletId: w2,
        fromAmountMinor: 2000,
        toAmountMinor: 2000,
        rate: 1.0,
        valueDate: date,
        note: 'Kira ödemesi',
      );

      final List<Transaction> legs =
          await db.transactionDao.getTransferLegs(groupId);
      for (final Transaction leg in legs) {
        expect(leg.note, startsWith('Kira ödemesi'));
        expect(leg.note, contains('\n'));
        expect(leg.note, contains('Transfer:'));
      }
    });
  });
}
