import 'package:freezed_annotation/freezed_annotation.dart';

import '../database/tables/enums.dart';

part 'account.freezed.dart';

/// Domain model for an account (groups one or more wallets).
///
/// A pure Freezed value type — no JSON, no Drift types. Mappers translate to and
/// from the Drift row (PROJECT_PLAN §4, Phase 2).
@freezed
abstract class Account with _$Account {
  const factory Account({
    required int id,
    required String name,
    required AccountType type,
    required int colorValue,
    required int iconCodePoint,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Account;
}
