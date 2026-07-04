import '../../data/database/app_database.dart' show AppDatabase;
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/mappers/account_mapper.dart';
import '../../data/models/mappers/category_mapper.dart';
import '../../data/models/mappers/wallet_mapper.dart';
import '../../data/models/transaction.dart';
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

/// Replaces a category with [category] (its new value) after the window.
class UpdateCategoryAction extends UndoableAction {
  const UpdateCategoryAction({required this.category, required this.label});

  /// The new category value to persist and to show optimistically.
  final Category category;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.category, category.id);

  @override
  UndoEffect get effect => UpdateEffect(category);

  @override
  Future<bool> canCommit(AppDatabase db) async => true;

  @override
  Future<void> commit(AppDatabase db) =>
      db.categoryDao.updateCategory(category.toRow());
}

/// Deletes a category after the undo window.
///
/// [canCommit] returns `false` when the category is unsafe to HARD-delete —
/// i.e. it has child categories, or it is referenced by any transaction or
/// recurring-rule link. In those cases the UI archives instead of deleting
/// (PROJECT_PLAN Phase 4), preserving history and avoiding FK violations.
class DeleteCategoryAction extends UndoableAction {
  const DeleteCategoryAction({required this.category, required this.label});

  final Category category;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.category, category.id);

  @override
  UndoEffect get effect => const DeleteEffect();

  @override
  Future<bool> canCommit(AppDatabase db) async {
    if ((await db.categoryDao.childCount(category.id)) > 0) {
      return false;
    }
    return !(await db.categoryDao.isReferenced(category.id));
  }

  @override
  Future<void> commit(AppDatabase db) =>
      db.categoryDao.deleteCategory(category.id);
}

/// Deletes a transaction after the undo window. A transaction is always
/// hard-deletable (its category links cascade), so [canCommit] is `true`.
class DeleteTransactionAction extends UndoableAction {
  const DeleteTransactionAction({
    required this.transaction,
    required this.label,
  });

  final Transaction transaction;

  @override
  final String label;

  @override
  EntityRef get target => EntityRef(UndoEntityType.transaction, transaction.id);

  @override
  UndoEffect get effect => const DeleteEffect();

  @override
  Future<bool> canCommit(AppDatabase db) async => true;

  @override
  Future<void> commit(AppDatabase db) =>
      db.transactionDao.deleteTransaction(transaction.id);
}
