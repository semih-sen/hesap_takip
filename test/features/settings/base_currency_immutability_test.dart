import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/repositories/settings_repository.dart';

/// §E.6: changing the base currency must NOT retroactively rewrite any existing
/// transaction's snapshotted rate/base amount (PROJECT_PLAN §6). Only the
/// settings row changes, affecting new writes going forward.
void main() {
  test('changing base currency leaves existing snapshots untouched', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final int acc = await db.accountDao.createAccount(
      AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int wallet = await db.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: acc,
        name: 'USD',
        currencyCode: 'USD',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
    final int txnId = await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        walletId: wallet,
        type: TransactionType.expense,
        flowDirection: FlowDirection.outflow,
        status: TransactionStatus.completed,
        amountMinor: 1000, // 10 USD
        currencyCode: 'USD',
        exchangeRateToBase: Decimal.parse('30'), // snapshotted against TRY
        baseAmountMinor: 30000,
        valueDate: DateTime(2026, 7, 5),
      ),
    );

    final SettingsRepository repo = DriftSettingsRepository(db);
    expect((await repo.getSettings()).baseCurrencyCode, 'TRY');

    await repo.setBaseCurrency('EUR');

    // Settings changed...
    expect((await repo.getSettings()).baseCurrencyCode, 'EUR');
    // ...but the transaction's snapshot is byte-for-byte the same.
    final Transaction txn = (await db.transactionDao.getTransactionById(txnId))!;
    expect(txn.exchangeRateToBase, Decimal.parse('30'));
    expect(txn.baseAmountMinor, 30000);
    expect(txn.currencyCode, 'USD');
  });
}
