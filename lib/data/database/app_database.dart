import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import 'connection.dart';
import 'converters/date_only_converter.dart';
import 'converters/decimal_converter.dart';
import 'daos/account_dao.dart';
import 'daos/category_dao.dart';
import 'daos/exchange_rate_dao.dart';
import 'daos/recurring_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/wallet_dao.dart';
import 'seed.dart';
import 'tables/accounts.dart';
import 'tables/app_settings.dart';
import 'tables/categories.dart';
import 'tables/enums.dart';
import 'tables/exchange_rates.dart';
import 'tables/recurring.dart';
import 'tables/transactions.dart';
import 'tables/wallets.dart';

part 'app_database.g.dart';

/// The application's Drift database (PROJECT_PLAN §5).
///
/// Schema history:
/// - v1: initial schema.
/// - v2 (Phase 9): adds the nullable `Transactions.settledContribMinor` column
///   (a partial-payment child's contribution in its parent's currency).
@DriftDatabase(
  tables: [
    Accounts,
    Wallets,
    Categories,
    Transactions,
    TransactionCategories,
    RecurringRules,
    RecurringRuleCategories,
    ExchangeRates,
    AppSettings,
  ],
  daos: [
    AccountDao,
    WalletDao,
    CategoryDao,
    TransactionDao,
    RecurringDao,
    ExchangeRateDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production database backed by an on-disk SQLite file.
  AppDatabase() : super(openConnection());

  /// Test/alternate constructor accepting any executor (e.g. an in-memory DB).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createRecurringGuardIndex();
      await _seedDefaults();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // v1 → v2: add the nullable child-contribution column. Additive only, so
      // existing rows keep NULL and no data is lost (Flag B-5).
      if (from < 2) {
        await m.addColumn(transactions, transactions.settledContribMinor);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // MANDATORY: SQLite ignores every foreign key (and therefore
      // KeyAction.cascade) unless this is enabled per-connection. Runs for the
      // app and for tests alike (PROJECT_PLAN Phase 1, task 6).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Partial UNIQUE index guaranteeing recurring-generation idempotency (§5.3).
  /// `@TableIndex` cannot express a `WHERE` clause, so it is created here.
  Future<void> _createRecurringGuardIndex() async {
    await customStatement(
      'CREATE UNIQUE INDEX ux_txn_recurring_date ON transactions '
      '(recurring_rule_id, value_date) WHERE recurring_rule_id IS NOT NULL;',
    );
  }

  /// Idempotent first-run seed: the singleton settings row and the default
  /// Turkish categories. Only ever invoked from `onCreate`.
  Future<void> _seedDefaults() async {
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        id: const Value(1),
        baseCurrencyCode: const Value('TRY'),
        firstDayOfWeek: const Value(1),
      ),
    );

    await batch((Batch b) {
      for (int i = 0; i < kDefaultCategories.length; i++) {
        final SeedCategory c = kDefaultCategories[i];
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: c.name,
            type: c.type,
            colorValue: c.colorValue,
            iconCodePoint: c.iconCodePoint,
            sortOrder: Value(i),
          ),
        );
      }
    });
  }
}
