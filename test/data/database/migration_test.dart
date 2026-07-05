import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';

/// Flag B-5: the v1 → v2 migration only ADDS the nullable
/// `settled_contrib_minor` column and must never wipe existing data.
///
/// The v1 fixture is built by opening the current (v2) schema on a temp file,
/// inserting a legacy row, then dropping the new column and stamping
/// `user_version = 1`. Reopening the same file makes Drift run `onUpgrade`.
void main() {
  test('v1 → v2 adds settledContribMinor and preserves existing data', () async {
    final Directory dir = await Directory.systemTemp.createTemp('hesap_mig');
    final File file = File('${dir.path}/mig.sqlite');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    // --- Build a v1-shaped database on disk with one legacy transaction. ---
    final AppDatabase setup = AppDatabase.forTesting(NativeDatabase(file));
    final int accountId = await setup.accountDao.createAccount(
      AccountsCompanion.insert(
        name: 'Nakit',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int walletId = await setup.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
    final int txnId = await setup.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 4200,
        currencyCode: 'TRY',
        exchangeRateToBase: Decimal.one,
        baseAmountMinor: 4200,
        valueDate: DateTime(2026, 3, 1),
        note: const Value('legacy'),
      ),
    );
    // Downgrade the on-disk schema to v1: drop the new column, stamp version 1.
    await setup.customStatement(
      'ALTER TABLE transactions DROP COLUMN settled_contrib_minor',
    );
    await setup.customStatement('PRAGMA user_version = 1');
    await setup.close();

    // --- Reopen: Drift runs onUpgrade (1 → 2). ---
    final AppDatabase migrated = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() => migrated.close());

    // The new column now exists.
    final columns = await migrated
        .customSelect('PRAGMA table_info(transactions)')
        .get();
    final Set<String> names = columns
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(names, contains('settled_contrib_minor'));

    // The legacy row survived, with the new column defaulting to null.
    final Transaction? txn = await migrated.transactionDao.getTransactionById(
      txnId,
    );
    expect(txn, isNotNull);
    expect(txn!.amountMinor, 4200);
    expect(txn.note, 'legacy');
    expect(txn.settledContribMinor, isNull);

    // Seed data survived too.
    final AppSetting settings = await migrated.settingsDao.getSettings();
    expect(settings.baseCurrencyCode, 'TRY');
  });
}
