import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/data/database/app_database.dart';
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:drift/drift.dart' show Value, Batch, Variable;
import 'package:drift/native.dart';
import 'package:hesap_takip/features/transactions/application/summary_providers.dart';
import 'package:hesap_takip/features/transactions/application/transactions_providers.dart';

void main() {
  test('investigate', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final int accountId = await db.accountDao.createAccount(
      AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int walletId = await db.walletDao.createWallet(
      WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );
    await db.batch((Batch batch) {
      for (int i = 0; i < 50; i++) {
        batch.insert(
          db.transactions,
          TransactionsCompanion.insert(
            walletId: walletId,
            type: TransactionType.expense,
            flowDirection: FlowDirection.outflow,
            status: TransactionStatus.completed,
            amountMinor: 5000,
            currencyCode: 'TRY',
            exchangeRateToBase: Decimal.one,
            baseAmountMinor: 5000,
            valueDate: DateTime(2026, 1, 1).add(Duration(days: i ~/ 10)),
          ),
        );
      }
    });

    final rows = await db.customSelect('SELECT value_date FROM transactions LIMIT 1').get();
    print('value_date: ${rows.first.read<String>('value_date')}');

    final res = await db.customSelect('''
      SELECT t.id AS id FROM transactions t 
      JOIN wallets w ON w.id = t.wallet_id 
      JOIN accounts acc ON acc.id = w.account_id 
      WHERE ((t.value_date >= ? AND t.value_date <= ?) OR (t.status = ? AND t.value_date < ?)) 
      ORDER BY t.value_date DESC, t.id DESC LIMIT ?
    ''', variables: [
      Variable.withString('0001-01-01'),
      Variable.withString('9999-12-31'),
      Variable.withInt(1),
      Variable.withString('0001-01-01'),
      Variable.withInt(50),
    ]).get();
    
    print('res length: ${res.length}');
    
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.read(summaryPeriodProvider.notifier).setAllTime();
    container.listen(visibleTransactionsProvider, (_, _) {});
    final list = await container.read(transactionListProvider.future);
    print('transactionListProvider list length: ${list.length}');
  });
}
