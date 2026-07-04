import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts.dart';

part 'account_dao.g.dart';

/// Data access for [Accounts]. DAOs are the boundary for raw SQL; the app layer
/// never queries the database directly (PROJECT_PLAN §2.8).
@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<int> createAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(Account entry) => update(accounts).replace(entry);

  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Account>> getAllAccounts() => _ordered().get();

  Stream<List<Account>> watchAllAccounts() => _ordered().watch();

  SimpleSelectStatement<$AccountsTable, Account> _ordered() =>
      select(accounts)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
}
