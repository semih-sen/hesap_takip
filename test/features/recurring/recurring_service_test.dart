import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/recurring/services/recurring_service.dart';

/// Phase 10: recurring-rule generation. Occurrences dated on-or-before `now`
/// are emitted (pending unless autoPost), idempotently, with a snapshotted base
/// amount; the 31st-of-month clamp marches without drift.
void main() {
  late AppDatabase db;
  late RecurringService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = RecurringService(db, const CurrencyService());
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

  Future<int> seedRule({
    required int walletId,
    TransactionType type = TransactionType.expense,
    FlowDirection flow = FlowDirection.outflow,
    int amountMinor = 10000,
    String code = 'TRY',
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int interval = 1,
    int? byMonthDay,
    int? byWeekday,
    required DateTime startDate,
    DateTime? endDate,
    int? maxOccurrences,
    bool autoPost = false,
    String? note,
  }) => db.recurringDao.createRule(
    RecurringRulesCompanion.insert(
      name: 'Kural',
      type: type,
      flowDirection: flow,
      walletId: walletId,
      amountMinor: amountMinor,
      currencyCode: code,
      frequency: frequency,
      interval: Value(interval),
      byMonthDay: Value(byMonthDay),
      byWeekday: Value(byWeekday),
      startDate: startDate,
      endDate: Value(endDate),
      maxOccurrences: Value(maxOccurrences),
      autoPost: Value(autoPost),
      note: Value(note),
    ),
  );

  Future<List<Transaction>> txns() => db.transactionDao.watchAllTransactions().first;

  RecurringRule ruleRow({
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int interval = 1,
    int? byMonthDay,
    int? byWeekday,
    required DateTime startDate,
  }) {
    final DateTime now = DateTime(2026, 1, 1);
    return RecurringRule(
      id: 1,
      name: 'r',
      type: TransactionType.expense,
      flowDirection: FlowDirection.outflow,
      walletId: 1,
      amountMinor: 100,
      currencyCode: 'TRY',
      frequency: frequency,
      interval: interval,
      byMonthDay: byMonthDay,
      byWeekday: byWeekday,
      startDate: startDate,
      generatedCount: 0,
      autoPost: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('nextOccurrenceAfter', () {
    test('first occurrence is startDate itself', () {
      final RecurringRule r = ruleRow(startDate: DateTime(2026, 3, 10));
      expect(
        service.nextOccurrenceAfter(DateTime(2026, 3, 9), r),
        DateTime(2026, 3, 10),
      );
    });

    test('daily honors interval > 1', () {
      final RecurringRule r = ruleRow(
        frequency: RecurrenceFrequency.daily,
        interval: 3,
        startDate: DateTime(2026, 3, 1),
      );
      expect(
        service.nextOccurrenceAfter(DateTime(2026, 3, 10), r),
        DateTime(2026, 3, 13),
      );
    });

    test('weekly lands on byWeekday within the target week', () {
      // Wednesday = 3. Anchor 2026-03-04 is a Wednesday; +1 week, keep Wed.
      final RecurringRule r = ruleRow(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        byWeekday: DateTime.wednesday,
        startDate: DateTime(2026, 3, 4),
      );
      final DateTime next = service.nextOccurrenceAfter(DateTime(2026, 3, 4), r)!;
      expect(next.weekday, DateTime.wednesday);
      expect(next, DateTime(2026, 3, 11));
    });

    test('monthly honors byMonthDay with clamp', () {
      final RecurringRule r = ruleRow(
        byMonthDay: 31,
        startDate: DateTime(2026, 1, 31),
      );
      expect(
        service.nextOccurrenceAfter(DateTime(2026, 1, 31), r),
        DateTime(2026, 2, 28),
      );
    });

    test('yearly advances 12 * interval months', () {
      final RecurringRule r = ruleRow(
        frequency: RecurrenceFrequency.yearly,
        interval: 2,
        startDate: DateTime(2026, 6, 15),
      );
      expect(
        service.nextOccurrenceAfter(DateTime(2026, 6, 15), r),
        DateTime(2028, 6, 15),
      );
    });
  });

  test('monthly-on-31st pending rule: Feb 28 then re-lands Mar 31; idempotent', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    await seedRule(
      walletId: wallet,
      frequency: RecurrenceFrequency.monthly,
      byMonthDay: 31,
      startDate: DateTime(2026, 1, 31),
    );

    // now = Apr 1 2026 (non-leap): occurrences Jan 31, Feb 28, Mar 31.
    final int inserted = await service.generateDueEntries(DateTime(2026, 4, 1));
    expect(inserted, 3);

    final List<Transaction> rows = await txns();
    final List<DateTime> dates = rows.map((t) => t.valueDate).toList()..sort();
    expect(dates, <DateTime>[
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
    ]);
    // All pending (autoPost=false), even though the dates are in the past.
    expect(rows.every((t) => t.status == TransactionStatus.pending), isTrue);

    // Re-run for the same now → zero new inserts (idempotency).
    final int again = await service.generateDueEntries(DateTime(2026, 4, 1));
    expect(again, 0);
    expect((await txns()).length, 3);
  });

  test('autoPost rule inserts completed rows and moves the balance', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    await seedRule(
      walletId: wallet,
      frequency: RecurrenceFrequency.monthly,
      amountMinor: 5000,
      autoPost: true,
      startDate: DateTime(2026, 1, 15),
    );

    await service.generateDueEntries(DateTime(2026, 3, 20)); // Jan, Feb, Mar
    final List<Transaction> rows = await txns();
    expect(rows.length, 3);
    expect(rows.every((t) => t.status == TransactionStatus.completed), isTrue);
    // 3 expense outflows of 5000 each.
    expect(
      await db.transactionDao.watchWalletBalanceMinor(wallet).first,
      -15000,
    );
  });

  test('endDate and maxOccurrences each stop generation', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    // endDate caps at Feb.
    await seedRule(
      walletId: wallet,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 1, 10),
      endDate: DateTime(2026, 2, 28),
    );
    final int a = await service.generateDueEntries(DateTime(2026, 6, 1));
    expect(a, 2); // Jan 10, Feb 10

    final int account2 = await seedAccount();
    final int wallet2 = await seedWallet(account2);
    await seedRule(
      walletId: wallet2,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 1, 10),
      maxOccurrences: 2,
    );
    final int b = await service.generateDueEntries(DateTime(2026, 6, 1));
    expect(b, 2); // capped at 2 occurrences
  });

  test('generated transaction carries the rule categories', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    final int cat = await db.categoryDao.createCategory(
      CategoriesCompanion.insert(
        name: 'Abonelik',
        type: CategoryType.expense,
        colorValue: 0xFF222222,
        iconCodePoint: 0xE002,
      ),
    );
    final int ruleId = await seedRule(
      walletId: wallet,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 1, 10),
    );
    await db.recurringDao.addCategory(ruleId, cat);

    await service.generateDueEntries(DateTime(2026, 1, 20)); // one occurrence
    final List<Transaction> rows = await txns();
    expect(rows.length, 1);
    final cats = await db.transactionDao.getCategoriesForTransaction(rows.single.id);
    expect(cats.map((c) => c.id), <int>[cat]);
  });

  test('same-currency snapshot: rate 1, base == amount', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account); // TRY, base is TRY
    await seedRule(
      walletId: wallet,
      amountMinor: 12345,
      startDate: DateTime(2026, 1, 10),
    );
    await service.generateDueEntries(DateTime(2026, 1, 20));
    final Transaction row = (await txns()).single;
    expect(row.exchangeRateToBase, Decimal.one);
    expect(row.baseAmountMinor, 12345);
  });

  test('cross-currency snapshot uses the cached rate as-of the value date', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account, code: 'USD');
    // 1 USD = 30 TRY, effective 2026-01-01.
    await db.exchangeRateDao.insertRate(
      ExchangeRatesCompanion.insert(
        baseCurrency: 'USD',
        quoteCurrency: 'TRY',
        rate: Decimal.parse('30'),
        asOfDate: DateTime(2026, 1, 1),
      ),
    );
    await seedRule(
      walletId: wallet,
      amountMinor: 1000, // 10.00 USD
      code: 'USD',
      startDate: DateTime(2026, 1, 10),
    );
    await service.generateDueEntries(DateTime(2026, 1, 20));
    final Transaction row = (await txns()).single;
    expect(row.currencyCode, 'USD');
    expect(row.exchangeRateToBase, Decimal.parse('30'));
    expect(row.baseAmountMinor, 30000); // 10 USD * 30 = 300.00 TRY
  });

  test('a future startDate generates nothing', () async {
    final int account = await seedAccount();
    final int wallet = await seedWallet(account);
    await seedRule(
      walletId: wallet,
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2026, 12, 1),
    );
    final int inserted = await service.generateDueEntries(DateTime(2026, 6, 1));
    expect(inserted, 0);
    expect((await txns()), isEmpty);
  });
}
