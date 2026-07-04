import 'package:drift/drift.dart' show Value;

import '../../../core/currency/money.dart';
import '../../database/app_database.dart' as db;
import '../wallet.dart';

/// Mappers between the Drift `Wallets` row and the [Wallet] domain model.

extension WalletRowMapper on db.Wallet {
  Wallet toDomain() => Wallet(
    id: id,
    accountId: accountId,
    name: name,
    initialBalance: Money(
      minorUnits: initialBalanceMinor,
      currencyCode: currencyCode,
    ),
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: isArchived,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension WalletDomainMapper on Wallet {
  db.Wallet toRow() => db.Wallet(
    id: id,
    accountId: accountId,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalance.minorUnits,
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: isArchived,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  db.WalletsCompanion toInsertCompanion() => db.WalletsCompanion.insert(
    accountId: accountId,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: Value(initialBalance.minorUnits),
    colorValue: colorValue,
    iconCodePoint: iconCodePoint,
    isArchived: Value(isArchived),
    sortOrder: Value(sortOrder),
  );
}
