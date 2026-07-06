import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/money.dart';
import 'package:hesap_takip/data/database/app_database.dart' show AppDatabase;
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/account.dart';
import 'package:hesap_takip/data/models/exchange_rate_entry.dart';
import 'package:hesap_takip/data/models/transaction.dart';
import 'package:hesap_takip/data/models/wallet.dart';
import 'package:hesap_takip/data/repositories/account_repository.dart';
import 'package:hesap_takip/data/repositories/exchange_rate_repository.dart';
import 'package:hesap_takip/data/repositories/settings_repository.dart';
import 'package:hesap_takip/data/repositories/transaction_repository.dart';
import 'package:hesap_takip/data/repositories/wallet_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // A domain Account for create(), with placeholder id/timestamps the DB
  // overrides.
  Account newAccount({String name = 'Banka'}) => Account(
    id: 0,
    name: name,
    type: AccountType.bank,
    colorValue: 0xFF102030,
    iconCodePoint: 0xE100,
    isArchived: false,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Wallet newWallet(int accountId, {String currencyCode = 'TRY'}) => Wallet(
    id: 0,
    accountId: accountId,
    name: 'Cüzdan',
    initialBalance: Money(minorUnits: 0, currencyCode: currencyCode),
    colorValue: 0xFF203040,
    iconCodePoint: 0xE101,
    isArchived: false,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Transaction newTransaction(int walletId) => Transaction(
    id: 0,
    walletId: walletId,
    type: TransactionType.expense,
    flowDirection: FlowDirection.outflow,
    status: TransactionStatus.completed,
    amount: const Money(minorUnits: 12345, currencyCode: 'TRY'),
    exchangeRateToBase: Decimal.one,
    baseAmountMinor: 12345,
    valueDate: DateTime(2026, 7, 4),
    createdAt: DateTime(2026, 7, 4),
    updatedAt: DateTime(2026, 7, 4),
  );

  group('AccountRepository', () {
    test('create returns a domain model on read', () async {
      final AccountRepository repo = DriftAccountRepository(db);
      final int id = await repo.createAccount(newAccount(name: 'Nakit'));

      final Account? loaded = await repo.findAccount(id);
      expect(loaded, isA<Account>());
      expect(loaded!.name, 'Nakit');
      expect(loaded.id, id);
    });

    test('watchAccounts emits inserts reactively (domain models)', () async {
      final AccountRepository repo = DriftAccountRepository(db);
      expect(await repo.watchAccounts().first, isEmpty);

      await repo.createAccount(newAccount(name: 'Banka'));
      final List<Account> rows = await repo.watchAccounts().firstWhere(
        (List<Account> list) => list.isNotEmpty,
      );
      expect(rows.single, isA<Account>());
      expect(rows.single.name, 'Banka');
    });

    test('archive sets isArchived without deleting', () async {
      final AccountRepository repo = DriftAccountRepository(db);
      final int id = await repo.createAccount(newAccount());
      await repo.archiveAccount(id);

      final Account? loaded = await repo.findAccount(id);
      expect(loaded, isNotNull);
      expect(loaded!.isArchived, isTrue);
    });
  });

  group('WalletRepository', () {
    test('watchWallets narrows by accountId', () async {
      final AccountRepository accounts = DriftAccountRepository(db);
      final WalletRepository wallets = DriftWalletRepository(db);
      final int accountA = await accounts.createAccount(newAccount(name: 'A'));
      final int accountB = await accounts.createAccount(newAccount(name: 'B'));

      await wallets.createWallet(newWallet(accountA, currencyCode: 'USD'));
      await wallets.createWallet(newWallet(accountB));

      final List<Wallet> forA = await wallets
          .watchWallets(accountId: accountA)
          .first;
      expect(forA.single.accountId, accountA);
      expect(forA.single.currencyCode, 'USD');
      expect(forA.single.initialBalance, isA<Money>());

      final List<Wallet> all = await wallets.watchWallets().first;
      expect(all.length, 2);
    });
  });

  group('TransactionRepository', () {
    test('create then reactive read returns a domain Transaction', () async {
      final AccountRepository accounts = DriftAccountRepository(db);
      final WalletRepository wallets = DriftWalletRepository(db);
      final TransactionRepository txns = DriftTransactionRepository(db, const CurrencyService([]));

      final int accountId = await accounts.createAccount(newAccount());
      final int walletId = await wallets.createWallet(newWallet(accountId));

      expect(await txns.watchTransactions().first, isEmpty);
      await txns.createTransaction(newTransaction(walletId));

      final List<Transaction> rows = await txns.watchTransactions().firstWhere(
        (List<Transaction> list) => list.isNotEmpty,
      );
      expect(rows.single, isA<Transaction>());
      expect(rows.single.amount.minorUnits, 12345);
      expect(rows.single.amount.currencyCode, 'TRY');
    });
  });

  group('ExchangeRateRepository', () {
    test('latestRate returns the newest rate at/-before a date', () async {
      final ExchangeRateRepository repo = DriftExchangeRateRepository(db);
      await repo.addRate(_rate('33.50', DateTime(2026, 1, 1)));
      await repo.addRate(_rate('34.10', DateTime(2026, 6, 1)));

      // On/-before 1 Mar → only the 1 Jan rate qualifies.
      final ExchangeRateEntry? atMarch = await repo.latestRate(
        'USD',
        'TRY',
        onOrBefore: DateTime(2026, 3, 1),
      );
      expect(atMarch!.rate, Decimal.parse('33.50'));

      // No bound → newest overall.
      final ExchangeRateEntry? latest = await repo.latestRate('USD', 'TRY');
      expect(latest!.rate, Decimal.parse('34.10'));

      // Unknown pair → null.
      expect(await repo.latestRate('EUR', 'TRY'), isNull);
    });
  });

  group('SettingsRepository', () {
    test('watchSettings emits the seeded domain Settings', () async {
      final SettingsRepository repo = DriftSettingsRepository(db);
      final settings = await repo.watchSettings().first;
      expect(settings.baseCurrencyCode, 'TRY');
      expect(settings.firstDayOfWeek, 1);
    });

    test('setBaseCurrency updates and re-emits', () async {
      final SettingsRepository repo = DriftSettingsRepository(db);
      await repo.setBaseCurrency('USD');
      final settings = await repo.getSettings();
      expect(settings.baseCurrencyCode, 'USD');
    });
  });
}

ExchangeRateEntry _rate(String rate, DateTime asOf) => ExchangeRateEntry(
  id: 0,
  baseCurrency: 'USD',
  quoteCurrency: 'TRY',
  rate: Decimal.parse(rate),
  asOfDate: asOf,
);


