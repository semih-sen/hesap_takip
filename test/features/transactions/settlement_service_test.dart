import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/features/transactions/services/settlement_service.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';

/// Phase 9 rework (§9): date-derived pending + settle-in-place. Full settlement
/// realizes the item; partial shrinks it and spawns a today-dated completed
/// child. Money math is status-based and counts each amount exactly once.
void main() {
  late AppDatabase db;
  late SettlementService service;
  late DriftTransactionRepository repo;

  final DateTime july15 = DateTime(2026, 7, 15);
  final DateTime aug15 = DateTime(2026, 8, 15);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final CurrencyService currency = CurrencyService(
      const [
  Currency(code: 'TRY', symbol: '₺', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'USD', symbol: '\$', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'EUR', symbol: '€', minorDigits: 2, symbolOnLeft: false),
  Currency(code: 'GBP', symbol: '£', minorDigits: 2, symbolOnLeft: true),
  Currency(code: 'JPY', symbol: '¥', minorDigits: 0, symbolOnLeft: true),

],
    );
    service = SettlementService(db, currency);
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

  /// Inserts a pending (future-dated) income/expense parent directly.
  Future<int> seedPending(
    int walletId, {
    required TransactionType type,
    required int amountMinor,
    int? baseAmountMinor,
    Decimal? rate,
    String code = 'TRY',
    DateTime? valueDate,
  }) => db.transactionDao.createTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      type: type,
      flowDirection: type == TransactionType.income
          ? FlowDirection.inflow
          : FlowDirection.outflow,
      status: TransactionStatus.pending,
      amountMinor: amountMinor,
      currencyCode: code,
      exchangeRateToBase: rate ?? Decimal.one,
      baseAmountMinor: baseAmountMinor ?? amountMinor,
      valueDate: valueDate ?? aug15,
    ),
  );

  Future<int> balance(int walletId) =>
      db.transactionDao.watchWalletBalanceMinor(walletId).first;

  Future<Transaction> row(int id) async =>
      (await db.transactionDao.getTransactionById(id))!;

  // 1) Status derivation.
  test('statusForValueDate: future → pending, today/past → completed', () {
    final DateTime today = DateTime.now();
    expect(
      statusForValueDate(today.add(const Duration(days: 3))),
      TransactionStatus.pending,
    );
    expect(
      statusForValueDate(today.subtract(const Duration(days: 3))),
      TransactionStatus.completed,
    );
  });

  // 2) Full settle.
  test('full settle realizes the item today; balance moves once', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int id = await seedPending(
      wallet,
      type: TransactionType.expense,
      amountMinor: 1000,
    );
    expect(await balance(wallet), 0); // pending never moves the balance

    final SettlementOutcome outcome = await service.settle(
      transactionId: id,
      paymentAmountMinor: 1000,
      paymentDate: july15,
    );
    expect(outcome.wasFull, isTrue);

    final Transaction settled = await row(id);
    expect(settled.status, TransactionStatus.completed);
    expect(settled.valueDate, july15);
    expect(settled.amountMinor, 1000);
    expect(await balance(wallet), -1000);
    // No child spawned on a full settle.
    expect(await db.transactionDao.countChildren(id), 0);
  });

  // 3) Partial settle.
  test('partial settle shrinks parent, spawns a today-dated completed child', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int catId = await db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: 'Kira',
        type: CategoryType.expense,
        colorValue: 0xFF222222,
        iconCodePoint: 0xE002,
      ),
    );
    final int id = await seedPending(
      wallet,
      type: TransactionType.expense,
      amountMinor: 1000,
    );
    await db.transactionDao.addCategory(id, catId);
    final int parentBaseBefore = (await row(id)).baseAmountMinor;

    final SettlementOutcome outcome = await service.settle(
      transactionId: id,
      paymentAmountMinor: 300,
      paymentDate: july15,
    );
    expect(outcome.wasFull, isFalse);
    final int childId = outcome.childId!;

    final Transaction parent = await row(id);
    final Transaction child = await row(childId);
    expect(parent.status, TransactionStatus.pending);
    expect(parent.amountMinor, 700);
    expect(child.status, TransactionStatus.completed);
    expect(child.amountMinor, 300);
    expect(child.valueDate, july15);
    expect(child.parentTransactionId, id);
    // Base conserved exactly (Flag E-2).
    expect(child.baseAmountMinor + parent.baseAmountMinor, parentBaseBefore);
    // Child carries the parent's category (E-6).
    final categories = await db.transactionDao.getCategoriesForTransaction(childId);
    expect(categories.map((c) => c.id), contains(catId));
    // Only the completed child moved the balance.
    expect(await balance(wallet), -300);
  });

  // 4) Sequence to zero.
  test('partial then remaining fully closes the parent; total counted once', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int id = await seedPending(
      wallet,
      type: TransactionType.expense,
      amountMinor: 1000,
    );

    await service.settle(transactionId: id, paymentAmountMinor: 300, paymentDate: july15);
    // The parent's remaining is now 700 — settling 700 is a FULL settle.
    final SettlementOutcome second = await service.settle(
      transactionId: id,
      paymentAmountMinor: 700,
      paymentDate: july15,
    );
    expect(second.wasFull, isTrue);

    final Transaction parent = await row(id);
    expect(parent.status, TransactionStatus.completed);
    expect(parent.amountMinor, 700); // 300 child + 700 parent = 1000
    expect(await balance(wallet), -1000);
  });

  // 5) Reverse a partial payment.
  test('reverseSettlementChild restores the parent and drops the child', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int id = await seedPending(
      wallet,
      type: TransactionType.income,
      amountMinor: 1000,
    );
    final int parentBaseBefore = (await row(id)).baseAmountMinor;
    final SettlementOutcome outcome = await service.settle(
      transactionId: id,
      paymentAmountMinor: 400,
      paymentDate: july15,
    );

    await service.reverseSettlementChild(outcome.childId!);

    final Transaction parent = await row(id);
    expect(parent.status, TransactionStatus.pending);
    expect(parent.amountMinor, 1000);
    expect(parent.baseAmountMinor, parentBaseBefore);
    expect(await db.transactionDao.getTransactionById(outcome.childId!), isNull);
  });

  // 6) Overpayment rejected.
  test('settling more than the remaining throws SettlementFailure', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int id = await seedPending(
      wallet,
      type: TransactionType.expense,
      amountMinor: 1000,
    );
    await expectLater(
      service.settle(transactionId: id, paymentAmountMinor: 1500),
      throwsA(
        isA<SettlementFailure>().having(
          (f) => f.reason,
          'reason',
          SettlementFailureReason.overpayment,
        ),
      ),
    );
    // Untouched.
    expect((await row(id)).amountMinor, 1000);
    expect((await row(id)).status, TransactionStatus.pending);
  });

  // 7) No double count in balance + summary.
  test('summary + balance count each amount exactly once', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int id = await seedPending(
      wallet,
      type: TransactionType.expense,
      amountMinor: 1000,
      valueDate: aug15, // future → pending
    );

    final DateRange period = DateRange(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 8, 31),
    );
    Future<SummaryData> summary() => repo
        .watchSummary(walletIds: <int>{wallet}, period: period, today: july15)
        .first;

    // Partial pay 300 (dated in-period).
    await service.settle(transactionId: id, paymentAmountMinor: 300, paymentDate: july15);
    SummaryData s = await summary();
    expect(s.paidExpenseMinor, 300); // Ödeme = the completed child
    expect(s.payableExpenseMinor, 700); // Borç = parent remaining
    expect(s.expenseTotalMinor, 1000); // Gider counted once
    expect(await balance(wallet), -300);

    // Settle the remaining 700 (full).
    await service.settle(transactionId: id, paymentAmountMinor: 700, paymentDate: july15);
    s = await summary();
    expect(s.paidExpenseMinor, 1000); // Ödeme = child + realized parent
    expect(s.payableExpenseMinor, 0); // Borç = 0
    expect(s.expenseTotalMinor, 1000);
    expect(await balance(wallet), -1000);
  });
}

