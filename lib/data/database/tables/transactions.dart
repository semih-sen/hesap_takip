import 'package:drift/drift.dart';

import '../converters/date_only_converter.dart';
import '../converters/decimal_converter.dart';
import 'categories.dart';
import 'enums.dart';
import 'recurring.dart';
import 'wallets.dart';

/// The ledger. Every money movement is a row here (PROJECT_PLAN §5.2).
///
/// Non-unique indexes (§5.3) are declared with [TableIndex]; the partial unique
/// recurring-idempotency index is created by raw statement in `AppDatabase`
/// (`@TableIndex` cannot express a `WHERE` clause).
@TableIndex(name: 'idx_txn_wallet', columns: {#walletId})
@TableIndex(name: 'idx_txn_value_date', columns: {#valueDate})
@TableIndex(name: 'idx_txn_status', columns: {#status})
@TableIndex(name: 'idx_txn_parent', columns: {#parentTransactionId})
@TableIndex(name: 'idx_txn_transfer_group', columns: {#transferGroupId})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get type => intEnum<TransactionType>()();
  IntColumn get flowDirection => intEnum<FlowDirection>()();
  IntColumn get status => intEnum<TransactionStatus>()();

  IntColumn get amountMinor => integer()(); // > 0, in txn currency
  TextColumn get currencyCode =>
      text().withLength(min: 3, max: 3)(); // snapshot
  // Snapshot of the rate to the base currency, stored exactly as text.
  TextColumn get exchangeRateToBase => text().map(const DecimalConverter())();
  IntColumn get baseAmountMinor => integer()(); // snapshot in base currency

  // Date-only, stored as ISO 'yyyy-MM-dd' text (§7).
  TextColumn get valueDate => text().map(const DateOnlyConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get payee => text().nullable()();

  // Partial-payment linkage.
  IntColumn get parentTransactionId =>
      integer().nullable().references(Transactions, #id)();
  IntColumn get plannedAmountMinor => integer().nullable()(); // parents only
  IntColumn get settledAmountMinor =>
      integer().nullable().withDefault(const Constant(0))(); // parents, cached

  // Recurring + transfer linkage.
  IntColumn get recurringRuleId =>
      integer().nullable().references(RecurringRules, #id)();
  TextColumn get transferGroupId => text().nullable()(); // uuid, links legs

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Transaction ↔ Category many-to-many with optional per-category split
/// (PROJECT_PLAN §5.2). Deleting a transaction cascades to its links here.
@DataClassName('TransactionCategory')
@TableIndex(name: 'idx_txncat_category', columns: {#categoryId})
class TransactionCategories extends Table {
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get allocatedAmountMinor =>
      integer().nullable()(); // null = whole txn

  @override
  Set<Column> get primaryKey => {transactionId, categoryId};
}
