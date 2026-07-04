import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/mappers/transaction_mapper.dart';
import '../models/transaction.dart';

part 'transaction_repository.g.dart';

/// Reactive data API for ledger transactions, returning DOMAIN [Transaction]
/// models. Feature-specific queries (summary, filtered list, partial-payment,
/// transfer) arrive with their own phases — this is the core read/write surface.
abstract interface class TransactionRepository {
  /// Transactions newest-first; narrowed to [walletId] when given.
  Stream<List<Transaction>> watchTransactions({int? walletId});

  /// The transaction with [id], or `null`.
  Future<Transaction?> findTransaction(int id);

  /// Inserts [transaction] and returns the new row id.
  Future<int> createTransaction(Transaction transaction);

  /// Replaces the stored transaction matching [transaction]'s id.
  Future<void> updateTransaction(Transaction transaction);

  /// Hard-deletes the transaction (cascades its category links).
  Future<void> deleteTransaction(int id);
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Transaction>> watchTransactions({int? walletId}) {
    final Stream<List<db.Transaction>> rows = walletId == null
        ? _db.transactionDao.watchAllTransactions()
        : _db.transactionDao.watchTransactionsForWallet(walletId);
    return rows.map((list) => list.map((row) => row.toDomain()).toList());
  }

  @override
  Future<Transaction?> findTransaction(int id) async =>
      (await _db.transactionDao.getTransactionById(id))?.toDomain();

  @override
  Future<int> createTransaction(Transaction transaction) =>
      _db.transactionDao.createTransaction(transaction.toInsertCompanion());

  @override
  Future<void> updateTransaction(Transaction transaction) =>
      _db.transactionDao.updateTransaction(transaction.toRow());

  @override
  Future<void> deleteTransaction(int id) =>
      _db.transactionDao.deleteTransaction(id);
}

/// App-lifetime singleton transaction repository.
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    DriftTransactionRepository(ref.watch(appDatabaseProvider));
