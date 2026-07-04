import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/undo/entity_actions.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/data/models/wallet.dart';
import 'package:hesap_takip/features/wallets/application/wallets_providers.dart';

/// Exercises the real provider graph: repo stream → visibleWallets overlay →
/// UndoService. A long window (default) ensures no auto-commit mid-test.
void main() {
  test('delete-via-undo hides the wallet, then undo restores it', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final int accountId = await database.accountDao.createAccount(
      db.AccountsCompanion.insert(
        name: 'Hesap',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
    );
    final int walletId = await database.walletDao.createWallet(
      db.WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cüzdan',
        currencyCode: 'TRY',
        colorValue: 0xFF111111,
        iconCodePoint: 0xE001,
      ),
    );

    // Keep the visible provider (and its stream) alive across reads.
    container.listen(
      visibleWalletsProvider(accountId),
      (_, _) {},
      fireImmediately: true,
    );
    // Wait for the first stream emission.
    await container.read(walletsStreamProvider(accountId).future);

    List<Wallet> visible() => container.read(visibleWalletsProvider(accountId));
    expect(visible().map((Wallet w) => w.id), contains(walletId));

    // Queue a delete (default 4.5s window → no commit during the test).
    final Wallet wallet = visible().firstWhere((Wallet w) => w.id == walletId);
    final String id = (await container
        .read(undoServiceProvider)
        .enqueue(DeleteWalletAction(wallet: wallet, label: 'silindi')))!;
    await Future<void>.delayed(Duration.zero); // let the overlay recompute

    // Optimistically gone even though the DB row still exists.
    expect(visible().where((Wallet w) => w.id == walletId), isEmpty);
    expect(await database.walletDao.getWalletById(walletId), isNotNull);

    // Undo → the wallet reappears (and the timer is cancelled).
    container.read(undoServiceProvider).undo(id);
    await Future<void>.delayed(Duration.zero);
    expect(visible().map((Wallet w) => w.id), contains(walletId));
  });
}
