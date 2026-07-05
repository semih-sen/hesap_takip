import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/features/transactions/services/partial_payment_service.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';

/// Phase 9 (§B.9): a bill settles across multiple payments and currencies; the
/// parent flips to completed exactly when fully settled; reversing/deleting
/// children reopens or clears the parent; balances and summary reflect ONLY
/// completed children (parents are never double-counted).
void main() {
  late AppDatabase db;
  late PartialPaymentService service;
  late DriftTransactionRepository repo;

  final DateRange july = DateRange(
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 31),
  );
  final DateTime endOfJuly = DateTime(2026, 7, 31);
  final DateTime july10 = DateTime(2026, 7, 10);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PartialPaymentService(db, const CurrencyService());
    repo = DriftTransactionRepository(db);
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

  Future<int> seedWallet(int accountId, {String code = 'TRY'}) =>
      db.walletDao.createWallet(
        WalletsCompanion.insert(
          accountId: accountId,
          name: 'Cüzdan-$code',
          currencyCode: code,
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );

  Future<int> balance(int walletId) =>
      db.transactionDao.watchWalletBalanceMinor(walletId).first;

  Future<SummaryData> summary() => repo
      .watchSummary(walletIds: const <int>{}, period: july, today: endOfJuly)
      .first;

  test('lifecycle: pay, settle, reverse — balances follow completed children', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);

    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );

    // Parent never moves the balance.
    expect(await balance(wallet), 0);

    // First payment: 300 → pending, settled 300.
    final int child1 = await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 300,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );
    Transaction parent = (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 300);
    expect(parent.status, TransactionStatus.pending);
    expect(await balance(wallet), -300);

    // Second payment: 700 → parent flips completed.
    final int child2 = await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 700,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );
    parent = (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 1000);
    expect(parent.status, TransactionStatus.completed);
    // Both children count, parent excluded → −1000 exactly once (not −2000).
    expect(await balance(wallet), -1000);

    // Reverse the 700 child → parent reopens pending, settled back to 300.
    await service.reversePayment(child2);
    parent = (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 300);
    expect(parent.status, TransactionStatus.pending);
    expect(await balance(wallet), -300);
    expect(await db.transactionDao.getTransactionById(child2), isNull);
    expect(await db.transactionDao.getTransactionById(child1), isNotNull);
  });

  test('cross-currency: TRY bill paid from a USD wallet settles exactly', () async {
    final int account = await seedAccount();
    final int tryWallet = await seedWallet(account);
    final int usdWallet = await seedWallet(account, code: 'USD');

    // Parent 600.00 TRY (base = TRY).
    final int parentId = await service.createBill(
      walletId: tryWallet,
      type: TransactionType.expense,
      plannedAmountMinor: 60000,
      valueDate: july10,
      categoryIds: const <int>[],
    );

    // Two USD payments of 10.00 USD at 30 TRY/USD → 300.00 TRY each.
    final Decimal rate = Decimal.fromInt(30);
    final int child1 = await service.applyPayment(
      parentId: parentId,
      sourceWalletId: usdWallet,
      paymentAmountMinor: 1000, // 10.00 USD
      rateToParentCurrency: rate,
      rateToBase: rate,
      valueDate: july10,
    );
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: usdWallet,
      paymentAmountMinor: 1000,
      rateToParentCurrency: rate,
      rateToBase: rate,
      valueDate: july10,
    );

    final Transaction parent =
        (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 60000); // exact settlement in TRY
    expect(parent.status, TransactionStatus.completed);

    final Transaction firstChild =
        (await db.transactionDao.getTransactionById(child1))!;
    expect(firstChild.currencyCode, 'USD');
    expect(firstChild.amountMinor, 1000); // stored in the wallet currency
    expect(firstChild.settledContribMinor, 30000); // parent-currency (TRY)
    expect(firstChild.baseAmountMinor, 30000); // via rateToBase
  });

  test('overpayment is rejected by default and allowed on request', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );

    await expectLater(
      service.applyPayment(
        parentId: parentId,
        sourceWalletId: wallet,
        paymentAmountMinor: 1500,
        rateToParentCurrency: Decimal.one,
        rateToBase: Decimal.one,
        valueDate: july10,
      ),
      throwsA(
        isA<OverpaymentFailure>()
            .having((f) => f.remainingMinor, 'remaining', 1000)
            .having((f) => f.attemptedMinor, 'attempted', 1500),
      ),
    );

    // No child was written on the rejected attempt.
    expect((await db.transactionDao.getChildren(parentId)), isEmpty);

    // With allowOverpayment the payment goes through and the parent completes.
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 1500,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
      allowOverpayment: true,
    );
    final Transaction parent =
        (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 1500);
    expect(parent.status, TransactionStatus.completed);
  });

  test('deleteBill guards children unless cascade', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );
    final int childId = await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 400,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );

    await expectLater(
      service.deleteBill(parentId),
      throwsA(
        isA<ParentHasChildrenFailure>().having((f) => f.childCount, 'count', 1),
      ),
    );
    // Nothing was deleted.
    expect(await db.transactionDao.getTransactionById(parentId), isNotNull);
    expect(await db.transactionDao.getTransactionById(childId), isNotNull);

    await service.deleteBill(parentId, cascade: true);
    expect(await db.transactionDao.getTransactionById(parentId), isNull);
    expect(await db.transactionDao.getTransactionById(childId), isNull);
  });

  test('recomputeSettled repairs a corrupted cached total', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 300,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );

    // Corrupt the cached settled total and status.
    Transaction parent = (await db.transactionDao.getTransactionById(parentId))!;
    await db.transactionDao.updateTransaction(
      parent.copyWith(
        settledAmountMinor: const Value(99999),
        status: TransactionStatus.completed,
      ),
    );

    await service.recomputeSettled(parentId);
    parent = (await db.transactionDao.getTransactionById(parentId))!;
    expect(parent.settledAmountMinor, 300);
    expect(parent.status, TransactionStatus.pending);
  });

  test('BalanceService does not double-count a fully-settled parent', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.expense,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 600,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 400,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );

    // Parent is now completed but still excluded → −1000, not −2000.
    expect(await balance(wallet), -1000);
  });

  test('summary never double-counts parent vs children (Gelir=Tahsilat+Alacak)', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int parentId = await service.createBill(
      walletId: wallet,
      type: TransactionType.income,
      plannedAmountMinor: 1000,
      valueDate: july10,
      categoryIds: const <int>[],
    );

    // One completed child of 300.
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 300,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );

    SummaryData s = await summary();
    expect(s.collectedIncomeMinor, 300); // Tahsilat = the child
    expect(s.receivableIncomeMinor, 700); // Alacak = parent remaining
    expect(s.incomeTotalMinor, 1000); // Gelir = 300 + 700, NOT 1300
    expect(s.incomeTotalMinor, s.incomeTotalCheckMinor);

    // Fully pay → parent flips completed; children carry 1000.
    await service.applyPayment(
      parentId: parentId,
      sourceWalletId: wallet,
      paymentAmountMinor: 700,
      rateToParentCurrency: Decimal.one,
      rateToBase: Decimal.one,
      valueDate: july10,
    );
    s = await summary();
    expect(s.collectedIncomeMinor, 1000); // Tahsilat = both children
    expect(s.receivableIncomeMinor, 0); // Alacak = 0
    expect(s.incomeTotalMinor, 1000); // Gelir stays 1000
  });
}
