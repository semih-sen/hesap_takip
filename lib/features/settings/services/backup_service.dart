import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/app_database_provider.dart';

part 'backup_service.g.dart';

/// Thrown when an imported backup envelope is missing/invalid or targets an
/// unsupported (future) schema version.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// JSON export/import of the ENTIRE database (PROJECT_PLAN §11 / §E.5).
///
/// Uses each table row's generated `toJson`/`fromJson` with a [ValueSerializer]
/// that maps `Decimal` ↔ String (the default serializer can't encode Decimal).
/// Import is a destructive wipe-and-replace inside one transaction with FK
/// enforcement disabled for the duration, preserving every original primary key
/// so cross-references (walletId, parentTransactionId, transferGroupId, …) stay
/// intact.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// The backup ENVELOPE format version — deliberately separate from the DB
  /// [AppDatabase.schemaVersion] even though both are 2 today (§E.5).
  static const int backupFormatVersion = 2;

  static final ValueSerializer _serializer = const _DecimalAwareSerializer();

  /// Serializes the whole database to a JSON string.
  Future<String> exportToJson() async {
    Future<List<Map<String, dynamic>>> rows<T extends DataClass>(
      TableInfo<Table, T> table,
    ) async {
      final List<T> data = await _db.select(table).get();
      return data
          .map((T r) => r.toJson(serializer: _serializer))
          .toList(growable: false);
    }

    final AppSetting settings = await _db.settingsDao.getSettings();

    final Map<String, dynamic> envelope = <String, dynamic>{
      'backupFormatVersion': backupFormatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': await rows(_db.accounts),
      'wallets': await rows(_db.wallets),
      'categories': await rows(_db.categories),
      'transactions': await rows(_db.transactions),
      'transactionCategories': await rows(_db.transactionCategories),
      'recurringRules': await rows(_db.recurringRules),
      'recurringRuleCategories': await rows(_db.recurringRuleCategories),
      'exchangeRates': await rows(_db.exchangeRates),
      'settings': settings.toJson(serializer: _serializer),
    };
    return jsonEncode(envelope);
  }

  /// Wipes every table and restores from [jsonStr] atomically (§E.5). Throws
  /// [BackupFormatException] on an invalid/unsupported envelope BEFORE touching
  /// any data. After a successful restore the caller should ask the user to
  /// restart the app.
  Future<void> importFromJson(String jsonStr) async {
    final Map<String, dynamic> data = _parseEnvelope(jsonStr);

    List<Map<String, dynamic>> list(String key) =>
        ((data[key] as List<dynamic>?) ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    // Parse EVERYTHING before mutating, so a malformed row aborts with the DB
    // still intact.
    final List<Account> accounts = list(
      'accounts',
    ).map((m) => Account.fromJson(m, serializer: _serializer)).toList();
    final List<Wallet> wallets = list(
      'wallets',
    ).map((m) => Wallet.fromJson(m, serializer: _serializer)).toList();
    final List<Category> categories = list(
      'categories',
    ).map((m) => Category.fromJson(m, serializer: _serializer)).toList();
    final List<Transaction> transactions = list(
      'transactions',
    ).map((m) => Transaction.fromJson(m, serializer: _serializer)).toList();
    final List<TransactionCategory> txnCategories = list('transactionCategories')
        .map((m) => TransactionCategory.fromJson(m, serializer: _serializer))
        .toList();
    final List<RecurringRule> rules = list(
      'recurringRules',
    ).map((m) => RecurringRule.fromJson(m, serializer: _serializer)).toList();
    final List<RecurringRuleCategory> ruleCategories =
        list('recurringRuleCategories')
            .map(
              (m) => RecurringRuleCategory.fromJson(m, serializer: _serializer),
            )
            .toList();
    final List<ExchangeRate> rates = list(
      'exchangeRates',
    ).map((m) => ExchangeRate.fromJson(m, serializer: _serializer)).toList();
    final AppSetting settings = AppSetting.fromJson(
      (data['settings'] as Map<String, dynamic>?) ??
          <String, dynamic>{'id': 1, 'baseCurrencyCode': 'TRY', 'firstDayOfWeek': 1},
      serializer: _serializer,
    );

    // FK enforcement can't be toggled inside a transaction, so disable it around
    // the whole wipe-and-restore (§E.5).
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        // Wipe (order irrelevant with FKs off, but delete links first anyway).
        await _db.delete(_db.transactionCategories).go();
        await _db.delete(_db.recurringRuleCategories).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.recurringRules).go();
        await _db.delete(_db.wallets).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.exchangeRates).go();

        // Restore, preserving original primary keys (data classes carry their id).
        await _insertAll(_db.accounts, accounts);
        await _insertAll(_db.categories, categories);
        await _insertAll(_db.wallets, wallets);
        await _insertAll(_db.transactions, transactions);
        await _insertAll(_db.transactionCategories, txnCategories);
        await _insertAll(_db.recurringRules, rules);
        await _insertAll(_db.recurringRuleCategories, ruleCategories);
        await _insertAll(_db.exchangeRates, rates);

        // Settings is a singleton (id = 1).
        await _db
            .into(_db.appSettings)
            .insert(settings, mode: InsertMode.insertOrReplace);
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }

    // Post-import integrity check: any dangling FK means a corrupt backup.
    final List<QueryRow> problems = await _db
        .customSelect('PRAGMA foreign_key_check')
        .get();
    if (problems.isNotEmpty) {
      throw const BackupFormatException('foreign key check failed after import');
    }
  }

  Future<void> _insertAll<T extends DataClass>(
    TableInfo<Table, T> table,
    List<Insertable<T>> rows,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    await _db.batch((Batch b) => b.insertAll(table, rows));
  }

  Map<String, dynamic> _parseEnvelope(String jsonStr) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } on FormatException {
      throw const BackupFormatException('not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('not a backup object');
    }
    final Object? schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int) {
      throw const BackupFormatException('missing schemaVersion');
    }
    if (schemaVersion > _db.schemaVersion) {
      throw const BackupFormatException(
        'backup is from a newer app version (unsupported schemaVersion)',
      );
    }
    return decoded;
  }
}

/// A [ValueSerializer] that (de)serializes `Decimal` as its canonical String,
/// delegating everything else to the drift default. Needed because the default
/// serializer cannot encode/decode the `exchangeRateToBase` Decimal
/// type-converter column.
class _DecimalAwareSerializer implements ValueSerializer {
  const _DecimalAwareSerializer();

  static final ValueSerializer _inner = const ValueSerializer.defaults();

  @override
  T fromJson<T>(dynamic json) {
    if (json != null && (T == Decimal || T == _typeOf<Decimal?>())) {
      return Decimal.parse(json.toString()) as T;
    }
    return _inner.fromJson<T>(json);
  }

  @override
  dynamic toJson<T>(T value) {
    if (value is Decimal) {
      return value.toString();
    }
    return _inner.toJson<T>(value);
  }

  static Type _typeOf<X>() => X;
}

/// App-lifetime singleton [BackupService].
@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) =>
    BackupService(ref.watch(appDatabaseProvider));
