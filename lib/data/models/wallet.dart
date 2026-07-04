import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/currency/money.dart';

part 'wallet.freezed.dart';

/// Domain model for a wallet (belongs to one account, has its own currency).
///
/// The wallet's currency is carried by [initialBalance] (a [Money]); the
/// [currencyCode] getter exposes it without duplicating state.
@freezed
abstract class Wallet with _$Wallet {
  const Wallet._();

  const factory Wallet({
    required int id,
    required int accountId,
    required String name,
    required Money initialBalance,
    required int colorValue,
    required int iconCodePoint,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Wallet;

  /// The wallet's ISO 4217 currency code (from [initialBalance]).
  String get currencyCode => initialBalance.currencyCode;
}
