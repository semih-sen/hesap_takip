import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/daos/transaction_dao.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';

/// PROJECT_PLAN Phase 7, §5 + proactive flags F1–F5: the base-currency Summary
/// query sums the SNAPSHOTTED `base_amount_minor` for completed, non-transfer
/// rows in the period, honors the empty-set-means-all wallet rule, and counts a
/// multi-category transaction exactly once.
void main() {
  late AppDatabase db;

  /// July 2026, inclusive on both ends.
  final DateRange july = DateRange(
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 31),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
          name: 'Cüzdan',
          currencyCode: code,
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );

  Future<int> insertTxn(
    int walletId, {
    required TransactionType type,
    required int amountMinor,
    required int baseAmountMinor,
    TransactionStatus status = TransactionStatus.completed,
    String code = 'TRY',
    DateTime? valueDate,
  }) {
    final FlowDirection flow = type == TransactionType.income
        ? FlowDirection.inflow
        : FlowDirection.outflow;
    return db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        type: type,
        flowDirection: flow,
        status: status,
        amountMinor: amountMinor,
        currencyCode: code,
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: baseAmountMinor,
        valueDate: valueDate ?? DateTime(2026, 7, 10),
      ),
    );
  }

  Future<SummaryTotals> summary({
    Set<int> walletIds = const <int>{},
    DateRange? range,
  }) => db.transactionDao
      .watchSummaryTotals(range: range ?? july, walletIds: walletIds)
      .first;

  test('sums completed same-currency income/expense; net follows', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    await insertTxn(wallet,
        type: TransactionType.income, amountMinor: 10000, baseAmountMinor: 10000);
    await insertTxn(wallet,
        type: TransactionType.expense, amountMinor: 3000, baseAmountMinor: 3000);

    final SummaryTotals totals = await summary();
    expect(totals.incomeMinor, 10000);
    expect(totals.expenseMinor, 3000);
    // net is derived by SummaryData; here just confirm the raw legs.
    expect(totals.incomeMinor - totals.expenseMinor, 7000);
  });

  test('uses base_amount_minor, NOT amount_minor, for cross-currency', () async {
    final int account = await seedAccount();
    final int usdWallet = await seedWallet(account, code: 'USD');
    // 100 USD-cents snapshotted to 3500 TRY-kuruş at write time.
    await insertTxn(usdWallet,
        type: TransactionType.income,
        amountMinor: 100,
        baseAmountMinor: 3500,
        code: 'USD');

    final SummaryTotals totals = await summary();
    expect(totals.incomeMinor, 3500); // base snapshot
    expect(totals.incomeMinor, isNot(100)); // never the wallet-currency amount
  });

  test('excludes pending (non-completed) rows', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    await insertTxn(wallet,
        type: TransactionType.expense,
        amountMinor: 5000,
        baseAmountMinor: 5000,
        status: TransactionStatus.pending);

    final SummaryTotals totals = await summary();
    expect(totals.incomeMinor, 0);
    expect(totals.expenseMinor, 0);
  });

  test('excludes transfer-type rows (both legs)', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);
    // Out leg + in leg of a completed transfer.
    await insertTxn(w1,
        type: TransactionType.transfer,
        amountMinor: 2000,
        baseAmountMinor: 2000);
    await insertTxn(w2,
        type: TransactionType.transfer,
        amountMinor: 2000,
        baseAmountMinor: 2000);
    // A real income so the query has something non-zero to prove it still counts.
    await insertTxn(w1,
        type: TransactionType.income, amountMinor: 800, baseAmountMinor: 800);

    final SummaryTotals totals = await summary();
    expect(totals.incomeMinor, 800);
    expect(totals.expenseMinor, 0); // transfers never land in income/expense
  });

  test('empty walletIds counts ALL wallets; non-empty filters (F1)', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);
    await insertTxn(w1,
        type: TransactionType.income, amountMinor: 1000, baseAmountMinor: 1000);
    await insertTxn(w2,
        type: TransactionType.income, amountMinor: 4000, baseAmountMinor: 4000);

    // Empty set → ALL wallets (the OPPOSITE of watchWalletsBalanceMinor).
    final SummaryTotals all = await summary();
    expect(all.incomeMinor, 5000);

    // Non-empty set → only the named wallet.
    final SummaryTotals onlyW1 = await summary(walletIds: <int>{w1});
    expect(onlyW1.incomeMinor, 1000);

    final SummaryTotals onlyW2 = await summary(walletIds: <int>{w2});
    expect(onlyW2.incomeMinor, 4000);
  });

  test('excludes rows outside the period; boundaries are inclusive', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    // Just before the window.
    await insertTxn(wallet,
        type: TransactionType.income,
        amountMinor: 9999,
        baseAmountMinor: 9999,
        valueDate: DateTime(2026, 6, 30));
    // Exactly on start.
    await insertTxn(wallet,
        type: TransactionType.income,
        amountMinor: 100,
        baseAmountMinor: 100,
        valueDate: DateTime(2026, 7, 1));
    // Exactly on end.
    await insertTxn(wallet,
        type: TransactionType.expense,
        amountMinor: 200,
        baseAmountMinor: 200,
        valueDate: DateTime(2026, 7, 31));
    // Just after the window.
    await insertTxn(wallet,
        type: TransactionType.expense,
        amountMinor: 8888,
        baseAmountMinor: 8888,
        valueDate: DateTime(2026, 8, 1));

    final SummaryTotals totals = await summary();
    expect(totals.incomeMinor, 100); // only the July-01 income
    expect(totals.expenseMinor, 200); // only the July-31 expense
  });

  test('a multi-category transaction is counted once (no category join, F5)',
      () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int catA = await db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: 'A',
        type: CategoryType.expense,
        colorValue: 0xFF222222,
        iconCodePoint: 0xE100,
      ),
    );
    final int catB = await db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: 'B',
        type: CategoryType.expense,
        colorValue: 0xFF333333,
        iconCodePoint: 0xE101,
      ),
    );
    final int txn = await insertTxn(wallet,
        type: TransactionType.expense,
        amountMinor: 6000,
        baseAmountMinor: 6000);
    // Split across two categories: a JOIN-based sum would double it to 12000.
    await db.transactionDao
        .addCategory(txn, catA, allocatedAmountMinor: 2000);
    await db.transactionDao
        .addCategory(txn, catB, allocatedAmountMinor: 4000);

    final SummaryTotals totals = await summary();
    expect(totals.expenseMinor, 6000); // counted once, at transaction grain
  });

  test('re-emits when the ledger changes (reactive)', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);

    final Stream<SummaryTotals> stream = db.transactionDao
        .watchSummaryTotals(range: july, walletIds: const <int>{});
    final Future<List<SummaryTotals>> firstTwo = stream.take(2).toList();

    // Give the initial emission a beat, then mutate the ledger.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await insertTxn(wallet,
        type: TransactionType.income, amountMinor: 500, baseAmountMinor: 500);

    final List<SummaryTotals> emissions = await firstTwo;
    expect(emissions.first.incomeMinor, 0);
    expect(emissions.last.incomeMinor, 500);
  });
}
