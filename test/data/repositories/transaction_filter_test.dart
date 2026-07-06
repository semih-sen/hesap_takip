import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/money.dart';
import 'package:hesap_takip/core/date/date_range.dart';
import 'package:hesap_takip/data/database/app_database.dart' hide Transaction;
import 'package:hesap_takip/data/database/daos/transaction_dao.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/transaction.dart';
import 'package:hesap_takip/data/models/transaction_filter.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';

/// SQL-level tests for the List-scope filter (PROJECT_PLAN §9 / §B.3): every
/// predicate must narrow in SQL, `initial()` returns all, empty walletIds means
/// ALL, and the window `limit` bounds the result.
void main() {
  late AppDatabase db;
  late DriftTransactionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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

  Future<int> seedWallet(int accountId, {String name = 'Cüzdan'}) =>
      db.walletDao.createWallet(
        WalletsCompanion.insert(
          accountId: accountId,
          name: name,
          currencyCode: 'TRY',
          colorValue: 0xFF111111,
          iconCodePoint: 0xE001,
        ),
      );

  Future<int> seedCategory({required String name, int sortOrder = 0}) =>
      db.categoryDao.createCategory(
        CategoriesCompanion.insert(
          name: name,
          type: CategoryType.expense,
          colorValue: 0xFF222222,
          iconCodePoint: 0xE002,
          sortOrder: Value(sortOrder),
        ),
      );

  Future<int> seedTxn(
    int walletId, {
    TransactionType type = TransactionType.expense,
    FlowDirection flow = FlowDirection.outflow,
    TransactionStatus status = TransactionStatus.completed,
    int amountMinor = 10000,
    DateTime? valueDate,
    String? note,
    String? payee,
    List<int> categoryIds = const <int>[],
  }) {
    final Transaction txn = Transaction(
      id: 0,
      walletId: walletId,
      type: type,
      flowDirection: flow,
      status: status,
      amount: Money(minorUnits: amountMinor, currencyCode: 'TRY'),
      exchangeRateToBase: Decimal.one,
      baseAmountMinor: amountMinor,
      valueDate: valueDate ?? DateTime(2026, 7, 5),
      note: note,
      payee: payee,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    return repo.createTransactionWithCategories(
      transaction: txn,
      links: <TransactionCategoryLink>[
        for (final int id in categoryIds)
          TransactionCategoryLink(categoryId: id),
      ],
    );
  }

  Future<List<TransactionListRowData>> query(
    TransactionFilter filter, {
    int limit = 1000,
    bool carryForwardOverdue = false,
  }) => repo
      .watchTransactionRows(
        filter,
        limit: limit,
        carryForwardOverdue: carryForwardOverdue,
      )
      .first;

  group('overdue carry-forward (§C.4)', () {
    // "Current" period = July 2026; a pending item overdue from June 2026.
    final DateRange july = DateRange(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );

    Future<(int, int)> seedOverdueAndCurrent(int w) async {
      final int overdue = await seedTxn(
        w,
        status: TransactionStatus.pending,
        valueDate: DateTime(2026, 6, 15), // before the period
      );
      final int current = await seedTxn(
        w,
        status: TransactionStatus.completed,
        valueDate: DateTime(2026, 7, 10), // in the period
      );
      return (overdue, current);
    }

    test('carryForwardOverdue: true returns the period row AND the overdue one',
        () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      await seedOverdueAndCurrent(w);

      final List<TransactionListRowData> rows = await query(
        TransactionFilter(range: july),
        carryForwardOverdue: true,
      );
      expect(rows.length, 2);
      expect(
        rows.map((TransactionListRowData r) => r.valueDate).toSet(),
        <DateTime>{DateTime(2026, 6, 15), DateTime(2026, 7, 10)},
      );
    });

    test('carryForwardOverdue: false returns ONLY the in-period row', () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      await seedOverdueAndCurrent(w);

      final List<TransactionListRowData> rows = await query(
        TransactionFilter(range: july),
      );
      expect(rows.length, 1);
      expect(rows.single.valueDate, DateTime(2026, 7, 10));
    });

    test('only PENDING rows before the period carry forward, not completed',
        () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      // A COMPLETED row before the period must NOT be carried forward.
      await seedTxn(
        w,
        status: TransactionStatus.completed,
        valueDate: DateTime(2026, 6, 15),
      );
      await seedTxn(
        w,
        status: TransactionStatus.completed,
        valueDate: DateTime(2026, 7, 10),
      );

      final List<TransactionListRowData> rows = await query(
        TransactionFilter(range: july),
        carryForwardOverdue: true,
      );
      expect(rows.length, 1);
      expect(rows.single.valueDate, DateTime(2026, 7, 10));
    });

    test(
      'an explicit status:completed filter suppresses carried pending rows '
      '(AND/OR precedence guard)',
      () async {
        final int a = await seedAccount();
        final int w = await seedWallet(a);
        await seedOverdueAndCurrent(w); // overdue is pending, current completed

        final List<TransactionListRowData> rows = await query(
          TransactionFilter(
            range: july,
            status: TransactionStatus.completed,
          ),
          carryForwardOverdue: true,
        );
        // The carried pending row is excluded by the top-level status = completed
        // predicate; only the completed in-period row survives. If the OR clause
        // weren't fully parenthesized, this would wrongly return both.
        expect(rows.length, 1);
        expect(rows.single.status, TransactionStatus.completed);
        expect(rows.single.valueDate, DateTime(2026, 7, 10));
      },
    );

    test('the flag is purely mechanical: a past-range query still carries '
        'earlier pending rows', () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      // Pending in May, "period" = June (a past month not containing today).
      await seedTxn(
        w,
        status: TransactionStatus.pending,
        valueDate: DateTime(2026, 5, 20),
      );
      final DateRange june = DateRange(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );
      final List<TransactionListRowData> rows = await query(
        TransactionFilter(range: june),
        carryForwardOverdue: true,
      );
      // DAO honors the flag regardless of whether the range contains today.
      expect(rows.single.valueDate, DateTime(2026, 5, 20));
    });
  });

  test(
    'row.accountColorValue is the owning account color, not the category color',
    () async {
      // Account color and category color are deliberately different so a bug
      // that reads the wrong source is caught.
      const int accountColor = 0xFF00A000;
      final int a = await db.accountDao.createAccount(
        AccountsCompanion.insert(
          name: 'Banka',
          type: AccountType.bank,
          colorValue: accountColor,
          iconCodePoint: 0xE000,
        ),
      );
      final int w = await seedWallet(a);
      final int cat = await seedCategory(name: 'Yemek'); // colorValue 0xFF222222
      await seedTxn(w, categoryIds: <int>[cat]);

      final List<TransactionListRowData> rows = await query(
        TransactionFilter.initial(),
      );
      expect(rows.single.accountColorValue, accountColor);
      expect(rows.single.categories.single.colorValue, 0xFF222222);
    },
  );

  test('initial() returns ALL rows (no narrowing)', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    await seedTxn(w);
    await seedTxn(w);
    await seedTxn(w);

    final List<TransactionListRowData> rows = await query(
      TransactionFilter.initial(),
    );
    expect(rows.length, 3);
  });

  test('empty walletIds means ALL wallets', () async {
    final int a = await seedAccount();
    final int w1 = await seedWallet(a, name: 'A');
    final int w2 = await seedWallet(a, name: 'B');
    await seedTxn(w1);
    await seedTxn(w2);

    final List<TransactionListRowData> rows = await query(
      const TransactionFilter(walletIds: <int>{}),
    );
    expect(rows.length, 2);
  });

  test('walletIds narrows to the selected wallets', () async {
    final int a = await seedAccount();
    final int w1 = await seedWallet(a, name: 'A');
    final int w2 = await seedWallet(a, name: 'B');
    await seedTxn(w1);
    await seedTxn(w1);
    await seedTxn(w2);

    final List<TransactionListRowData> rows = await query(
      TransactionFilter(walletIds: <int>{w1}),
    );
    expect(rows.length, 2);
    expect(rows.every((TransactionListRowData r) => r.walletId == w1), isTrue);
  });

  test('categoryIds narrows via membership', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    final int food = await seedCategory(name: 'Yemek');
    final int bills = await seedCategory(name: 'Faturalar');
    await seedTxn(w, categoryIds: <int>[food]);
    await seedTxn(w, categoryIds: <int>[bills]);
    await seedTxn(w); // no category

    final List<TransactionListRowData> rows = await query(
      TransactionFilter(categoryIds: <int>{food}),
    );
    expect(rows.length, 1);
    expect(rows.single.categories.single.name, 'Yemek');
  });

  test('type narrows', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    await seedTxn(
      w,
      type: TransactionType.expense,
      flow: FlowDirection.outflow,
    );
    await seedTxn(w, type: TransactionType.income, flow: FlowDirection.inflow);

    final List<TransactionListRowData> rows = await query(
      const TransactionFilter(type: TransactionType.income),
    );
    expect(rows.length, 1);
    expect(rows.single.type, TransactionType.income);
  });

  test('status narrows', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    await seedTxn(w, status: TransactionStatus.completed);
    await seedTxn(w, status: TransactionStatus.pending);

    final List<TransactionListRowData> rows = await query(
      const TransactionFilter(status: TransactionStatus.pending),
    );
    expect(rows.length, 1);
    expect(rows.single.status, TransactionStatus.pending);
  });

  test('date range narrows (inclusive) on valueDate', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    await seedTxn(w, valueDate: DateTime(2026, 7, 1));
    await seedTxn(w, valueDate: DateTime(2026, 7, 10));
    await seedTxn(w, valueDate: DateTime(2026, 7, 20));

    final List<TransactionListRowData> rows = await query(
      TransactionFilter(
        range: DateRange(
          start: DateTime(2026, 7, 5),
          end: DateTime(2026, 7, 15),
        ),
      ),
    );
    expect(rows.length, 1);
    expect(rows.single.valueDate, DateTime(2026, 7, 10));
  });

  test('search matches note, payee, or category name', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    final int cat = await seedCategory(name: 'Ulaşım');
    await seedTxn(w, note: 'benzin aldım');
    await seedTxn(w, payee: 'Shell');
    await seedTxn(w, categoryIds: <int>[cat]);
    await seedTxn(w, note: 'alakasız');

    expect((await query(const TransactionFilter(search: 'benzin'))).length, 1);
    expect((await query(const TransactionFilter(search: 'Shell'))).length, 1);
    expect((await query(const TransactionFilter(search: 'Ulaşım'))).length, 1);
    expect((await query(const TransactionFilter(search: 'yok'))).length, 0);
  });

  test('search treats LIKE wildcards literally', () async {
    final int a = await seedAccount();
    final int w = await seedWallet(a);
    await seedTxn(w, note: 'indirim %50');
    await seedTxn(w, note: 'normal');

    // '%' must match a literal percent, not "any string".
    expect((await query(const TransactionFilter(search: '%50'))).length, 1);
  });

  test('multiple predicates combine (AND)', () async {
    final int a = await seedAccount();
    final int w1 = await seedWallet(a, name: 'A');
    final int w2 = await seedWallet(a, name: 'B');
    await seedTxn(w1, type: TransactionType.income, flow: FlowDirection.inflow);
    await seedTxn(w1, type: TransactionType.expense);
    await seedTxn(w2, type: TransactionType.income, flow: FlowDirection.inflow);

    final List<TransactionListRowData> rows = await query(
      TransactionFilter(walletIds: <int>{w1}, type: TransactionType.income),
    );
    expect(rows.length, 1);
    expect(rows.single.walletId, w1);
    expect(rows.single.type, TransactionType.income);
  });

  test(
    'rows carry ordered category chips (primary first by sortOrder)',
    () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      final int high = await seedCategory(name: 'Sonra', sortOrder: 10);
      final int low = await seedCategory(name: 'Önce', sortOrder: 1);
      await seedTxn(w, categoryIds: <int>[high, low]);

      final List<TransactionListRowData> rows = await query(
        TransactionFilter.initial(),
      );
      expect(
        rows.single.categories
            .map((TransactionRowCategory c) => c.name)
            .toList(),
        <String>['Önce', 'Sonra'],
      );
    },
  );

  group('pagination window', () {
    test('limit bounds the result; ordering is stable newest-first', () async {
      final int a = await seedAccount();
      final int w = await seedWallet(a);
      for (int i = 1; i <= 5; i++) {
        await seedTxn(w, valueDate: DateTime(2026, 7, i));
      }

      final List<TransactionListRowData> page1 = await query(
        TransactionFilter.initial(),
        limit: 2,
      );
      expect(page1.length, 2);
      // Newest first: 2026-07-05 then 2026-07-04.
      expect(page1[0].valueDate, DateTime(2026, 7, 5));
      expect(page1[1].valueDate, DateTime(2026, 7, 4));

      final List<TransactionListRowData> page2 = await query(
        TransactionFilter.initial(),
        limit: 4,
      );
      expect(page2.length, 4);
      // Growing the window keeps the same head order (stable).
      expect(
        page2.take(2).map((TransactionListRowData r) => r.valueDate),
        <DateTime>[DateTime(2026, 7, 5), DateTime(2026, 7, 4)],
      );
    });
  });
}
