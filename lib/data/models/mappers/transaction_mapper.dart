import 'package:drift/drift.dart' show Value;

import '../../../core/currency/money.dart';
import '../../database/app_database.dart' as db;
import '../transaction.dart';

/// Mappers between the Drift `Transactions` row and the [Transaction] domain
/// model. `amountMinor`+`currencyCode` compose into [Money]; the base-currency
/// snapshot stays a raw `int`; `valueDate` and `exchangeRateToBase` round-trip
/// exactly via their Drift type converters.

extension TransactionRowMapper on db.Transaction {
  Transaction toDomain() => Transaction(
    id: id,
    walletId: walletId,
    type: type,
    flowDirection: flowDirection,
    status: status,
    amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
    exchangeRateToBase: exchangeRateToBase,
    baseAmountMinor: baseAmountMinor,
    valueDate: valueDate,
    note: note,
    payee: payee,
    parentTransactionId: parentTransactionId,
    plannedAmountMinor: plannedAmountMinor,
    settledAmountMinor: settledAmountMinor,
    settledContribMinor: settledContribMinor,
    recurringRuleId: recurringRuleId,
    transferGroupId: transferGroupId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension TransactionDomainMapper on Transaction {
  db.Transaction toRow() => db.Transaction(
    id: id,
    walletId: walletId,
    type: type,
    flowDirection: flowDirection,
    status: status,
    amountMinor: amount.minorUnits,
    currencyCode: currencyCode,
    exchangeRateToBase: exchangeRateToBase,
    baseAmountMinor: baseAmountMinor,
    valueDate: valueDate,
    note: note,
    payee: payee,
    parentTransactionId: parentTransactionId,
    plannedAmountMinor: plannedAmountMinor,
    settledAmountMinor: settledAmountMinor,
    settledContribMinor: settledContribMinor,
    recurringRuleId: recurringRuleId,
    transferGroupId: transferGroupId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  db.TransactionsCompanion toInsertCompanion() =>
      db.TransactionsCompanion.insert(
        walletId: walletId,
        type: type,
        flowDirection: flowDirection,
        status: status,
        amountMinor: amount.minorUnits,
        currencyCode: currencyCode,
        exchangeRateToBase: exchangeRateToBase,
        baseAmountMinor: baseAmountMinor,
        valueDate: valueDate,
        note: Value(note),
        payee: Value(payee),
        parentTransactionId: Value(parentTransactionId),
        plannedAmountMinor: Value(plannedAmountMinor),
        // Absent when null so the column default (0) applies; parents carry a
        // real cached value.
        settledAmountMinor: settledAmountMinor == null
            ? const Value.absent()
            : Value(settledAmountMinor!),
        settledContribMinor: Value(settledContribMinor),
        recurringRuleId: Value(recurringRuleId),
        transferGroupId: Value(transferGroupId),
      );
}
