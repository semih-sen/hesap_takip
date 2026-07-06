
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/features/transactions/services/summary_data.dart';

/// Summary Card Refactor §A.8: the 9-cell base-currency summary sums snapshotted
/// `baseAmountMinor`, honors the completed/pending buckets, includes initial
/// balances + completed transfer legs in Row-1 (Decisions 1A/2A), and keeps the
/// invariants Gelir=Tahsilat+Alacak, Gider=Ödeme+Borç, Devredecek(N)=Devreden(N+1).
void main() {
  late AppDatabase db;
  late DriftTransactionRepository repo;

  // Contiguous months so the carry-forward continuity invariant is meaningful.
  final DateRange june = DateRange(
    start: DateTime(2026, 6, 1),
    end: DateTime(2026, 6, 30),
  );
  final DateRange july = DateRange(
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 31),
  );
  final DateRange august = DateRange(
    start: DateTime(2026, 8, 1),
    end: DateTime(2026, 8, 31),
  );
  final DateTime endOfJuly = DateTime(2026, 7, 31);

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

  Future<int> seedWallet(
    int accountId, {
    String code = 'TRY',
    int initialMinor = 0,
  }) => db.walletDao.createWallet(
    WalletsCompanion.insert(
      accountId: accountId,
      name: 'Cüzdan-$code-$initialMinor',
      currencyCode: code,
      initialBalanceMinor: Value(initialMinor),
      colorValue: 0xFF111111,
      iconCodePoint: 0xE001,
    ),
  );

  Future<int> insertTxn(
    int walletId, {
    required TransactionType type,
    required FlowDirection flow,
    required TransactionStatus status,
    required int amountMinor,
    required int baseAmountMinor,
    required DateTime valueDate,
    String code = 'TRY',
    String? transferGroupId,
  }) => db.transactionDao.createTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      type: type,
      flowDirection: flow,
      status: status,
      amountMinor: amountMinor,
      currencyCode: code,
      exchangeRateToBase: Decimal.one,
      baseAmountMinor: baseAmountMinor,
      valueDate: valueDate,
      transferGroupId: Value(transferGroupId),
    ),
  );

  Future<int> income(int w, int minor, DateTime d, TransactionStatus s) =>
      insertTxn(w,
          type: TransactionType.income,
          flow: FlowDirection.inflow,
          status: s,
          amountMinor: minor,
          baseAmountMinor: minor,
          valueDate: d);

  Future<int> expense(int w, int minor, DateTime d, TransactionStatus s) =>
      insertTxn(w,
          type: TransactionType.expense,
          flow: FlowDirection.outflow,
          status: s,
          amountMinor: minor,
          baseAmountMinor: minor,
          valueDate: d);

  Future<SummaryData> summary(DateRange period, {DateTime? today}) => repo
      .watchSummary(
        walletIds: const <int>{},
        period: period,
        today: today ?? endOfJuly,
      )
      .first;

  test('computes all 10 fields incl. cross-currency base snapshot', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account, initialMinor: 100000); // 1000.00
    final int w3 = await seedWallet(account, code: 'USD'); // cross-currency

    // June (before the July period).
    await income(w1, 50000, DateTime(2026, 6, 10), TransactionStatus.completed);
    await expense(w1, 20000, DateTime(2026, 6, 12), TransactionStatus.completed);
    // July flows.
    await income(w1, 30000, DateTime(2026, 7, 5), TransactionStatus.completed);
    await income(w1, 20000, DateTime(2026, 7, 20), TransactionStatus.pending);
    await expense(w1, 12000, DateTime(2026, 7, 10), TransactionStatus.completed);
    await expense(w1, 8000, DateTime(2026, 7, 25), TransactionStatus.pending);
    // Cross-currency income: amount 100 (USD) snapshotted to 3500 (TRY base).
    await insertTxn(w3,
        type: TransactionType.income,
        flow: FlowDirection.inflow,
        status: TransactionStatus.completed,
        amountMinor: 100,
        baseAmountMinor: 3500,
        valueDate: DateTime(2026, 7, 12),
        code: 'USD');

    final SummaryData s = await summary(july);

    // Row 3 — the base snapshot (3500), never the wallet amount (100).
    expect(s.collectedIncomeMinor, 33500); // 30000 + 3500
    expect(s.receivableIncomeMinor, 20000);
    expect(s.paidExpenseMinor, 12000);
    expect(s.payableExpenseMinor, 8000);
    // Row 2.
    expect(s.incomeTotalMinor, 53500);
    expect(s.expenseTotalMinor, 20000);
    expect(s.netBalanceMinor, 33500);
    // Row 1: initial 100000 + June net 30000 = 130000 carried over.
    expect(s.carriedOverMinor, 130000);
    expect(s.carryForwardMinor, 163500); // 130000 + 33500
    // Cash: initial 100000 + completed ≤ today (50000-20000+30000-12000+3500).
    expect(s.currentCashMinor, 151500);
    expect(s.baseCurrencyCode, 'TRY');

    // Invariants.
    expect(s.incomeTotalMinor, s.incomeTotalCheckMinor);
    expect(s.expenseTotalMinor, s.expenseTotalCheckMinor);
  });

  test('Devredecek(N) equals Devreden(N+1) across contiguous months', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account, initialMinor: 100000);
    await income(w1, 50000, DateTime(2026, 6, 10), TransactionStatus.completed);
    await expense(w1, 20000, DateTime(2026, 6, 12), TransactionStatus.completed);
    await income(w1, 30000, DateTime(2026, 7, 5), TransactionStatus.completed);
    await income(w1, 20000, DateTime(2026, 7, 20), TransactionStatus.pending);
    await expense(w1, 12000, DateTime(2026, 7, 10), TransactionStatus.completed);
    await expense(w1, 8000, DateTime(2026, 7, 25), TransactionStatus.pending);

    final SummaryData julyS = await summary(july);
    final SummaryData augS = await summary(august, today: DateTime(2026, 8, 31));
    expect(julyS.carryForwardMinor, augS.carriedOverMinor);

    // And the same for the June → July boundary.
    final SummaryData juneS =
        await summary(june, today: DateTime(2026, 6, 30));
    expect(juneS.carryForwardMinor, julyS.carriedOverMinor);
  });

  test('wallet filter narrows to the selected wallets', () async {
    final int account = await seedAccount();
    final int w1 = await seedWallet(account);
    final int w2 = await seedWallet(account);
    await income(w1, 1000, DateTime(2026, 7, 5), TransactionStatus.completed);
    await income(w2, 4000, DateTime(2026, 7, 6), TransactionStatus.completed);

    final SummaryData all = await summary(july);
    expect(all.incomeTotalMinor, 5000);

    final SummaryData onlyW1 = await repo
        .watchSummary(
          walletIds: <int>{w1},
          period: july,
          today: endOfJuly,
        )
        .first;
    expect(onlyW1.incomeTotalMinor, 1000);
  });

  test('archived wallets are excluded from an all-wallets summary', () async {
    final int account = await seedAccount();
    final int active = await seedWallet(account);
    final int archived = await seedWallet(account);
    await income(active, 1000, DateTime(2026, 7, 5), TransactionStatus.completed);
    await income(
        archived, 9999, DateTime(2026, 7, 6), TransactionStatus.completed);
    // Archive the second wallet.
    final Wallet row = (await db.walletDao.getWalletById(archived))!;
    await db.walletDao.updateWallet(row.copyWith(isArchived: true));

    final SummaryData s = await summary(july);
    expect(s.incomeTotalMinor, 1000); // archived wallet's 9999 excluded (A-3)
  });
}


