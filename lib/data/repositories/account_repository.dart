import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/account.dart';
import '../models/mappers/account_mapper.dart';

part 'account_repository.g.dart';

/// Reactive data API for accounts, returning DOMAIN [Account] models — never
/// Drift rows (PROJECT_PLAN §2.8, Phase 2).
abstract interface class AccountRepository {
  /// All accounts ordered by `sortOrder`, updating on every change.
  Stream<List<Account>> watchAccounts();

  /// The account with [id], or `null` if it does not exist.
  Future<Account?> findAccount(int id);

  /// Inserts [account] (its `id` and audit timestamps are DB-assigned) and
  /// returns the new row id.
  Future<int> createAccount(Account account);

  /// Replaces the stored account matching [account]'s id.
  Future<void> updateAccount(Account account);

  /// Soft-removes the account by setting `isArchived = true`.
  Future<void> archiveAccount(int id);

  /// Hard-deletes the account (blocked by FK if wallets still reference it).
  Future<void> deleteAccount(int id);

  /// Marks [id] as the default account (clearing any other default).
  Future<void> setDefaultAccount(int id);
}

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Account>> watchAccounts() => _db.accountDao
      .watchAllAccounts()
      .map((rows) => rows.map((row) => row.toDomain()).toList());

  @override
  Future<Account?> findAccount(int id) async =>
      (await _db.accountDao.getAccountById(id))?.toDomain();

  @override
  Future<int> createAccount(Account account) =>
      _db.accountDao.createAccount(account.toInsertCompanion());

  @override
  Future<void> updateAccount(Account account) =>
      _db.accountDao.updateAccount(account.toRow());

  @override
  Future<void> archiveAccount(int id) async {
    final db.Account? existing = await _db.accountDao.getAccountById(id);
    if (existing == null) {
      return;
    }
    await _db.accountDao.updateAccount(
      existing.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
  }

  @override
  Future<void> deleteAccount(int id) => _db.accountDao.deleteAccount(id);

  @override
  Future<void> setDefaultAccount(int id) => _db.accountDao.setDefaultAccount(id);
}

/// App-lifetime singleton account repository.
@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) =>
    DriftAccountRepository(ref.watch(appDatabaseProvider));
