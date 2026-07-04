import '../../data/database/app_database.dart' show AppDatabase;
import '../../data/models/account.dart';
import '../../data/models/mappers/account_mapper.dart';
import '../../data/models/mappers/wallet_mapper.dart';
import '../../data/models/wallet.dart';
import 'undoable_action.dart';

/// Concrete [UndoableAction]s wired by Phase 3 (accounts & wallets). Later
/// phases add transaction/category actions the same way. Each carries the
/// already-localized [label] its caller resolved from the ARB.

/// Deletes a wallet after the undo window. Blocked at enqueue if the wallet has
/// any transactions (FK-restricted → archive instead).
class DeleteWalletAction extends UndoableAction {
  const DeleteWalletAction({required this.wallet, required this.label});

  final Wallet wallet;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.wallet, wallet.id);

  @override
  UndoEffect get effect => const DeleteEffect();

  @override
  Future<bool> canCommit(AppDatabase db) async =>
      (await db.transactionDao.countForWallet(wallet.id)) == 0;

  @override
  Future<void> commit(AppDatabase db) => db.walletDao.deleteWallet(wallet.id);
}

/// Deletes an account after the undo window. Blocked at enqueue if the account
/// still has wallets (FK-restricted → remove/archive its wallets first).
class DeleteAccountAction extends UndoableAction {
  const DeleteAccountAction({required this.account, required this.label});

  final Account account;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.account, account.id);

  @override
  UndoEffect get effect => const DeleteEffect();

  @override
  Future<bool> canCommit(AppDatabase db) async =>
      (await db.walletDao.countForAccount(account.id)) == 0;

  @override
  Future<void> commit(AppDatabase db) =>
      db.accountDao.deleteAccount(account.id);
}

/// Replaces a wallet with [wallet] (its new value) after the window. The overlay
/// renders [wallet] immediately via [UpdateEffect].
class UpdateWalletAction extends UndoableAction {
  const UpdateWalletAction({required this.wallet, required this.label});

  /// The new wallet value to persist and to show optimistically.
  final Wallet wallet;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.wallet, wallet.id);

  @override
  UndoEffect get effect => UpdateEffect(wallet);

  @override
  Future<bool> canCommit(AppDatabase db) async => true;

  @override
  Future<void> commit(AppDatabase db) =>
      db.walletDao.updateWallet(wallet.toRow());
}

/// Replaces an account with [account] (its new value) after the window.
class UpdateAccountAction extends UndoableAction {
  const UpdateAccountAction({required this.account, required this.label});

  final Account account;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.account, account.id);

  @override
  UndoEffect get effect => UpdateEffect(account);

  @override
  Future<bool> canCommit(AppDatabase db) async => true;

  @override
  Future<void> commit(AppDatabase db) =>
      db.accountDao.updateAccount(account.toRow());
}

/// Toggles a wallet's `isArchived` flag after the window (a specialized update).
/// Archiving is non-destructive, so most callers apply it immediately; this
/// action exists for callers that want the undo affordance.
class ArchiveWalletAction extends UndoableAction {
  ArchiveWalletAction({
    required this.wallet,
    required this.archived,
    required this.label,
  }) : _updated = wallet.copyWith(isArchived: archived);

  /// The wallet before the toggle.
  final Wallet wallet;

  /// Desired archived state.
  final bool archived;

  final Wallet _updated;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.wallet, wallet.id);

  @override
  UndoEffect get effect => UpdateEffect(_updated);

  @override
  Future<bool> canCommit(AppDatabase db) async => true;

  @override
  Future<void> commit(AppDatabase db) =>
      db.walletDao.updateWallet(_updated.toRow());
}
