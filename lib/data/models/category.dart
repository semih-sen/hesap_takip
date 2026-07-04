import 'package:freezed_annotation/freezed_annotation.dart';

import '../database/tables/enums.dart';

part 'category.freezed.dart';

/// Domain model for a (hierarchical) income/expense category.
///
/// `parentId` is a nullable self-reference enabling parent/child hierarchies.
@freezed
abstract class Category with _$Category {
  const factory Category({
    required int id,
    required String name,
    required CategoryType type,
    int? parentId,
    required int colorValue,
    required int iconCodePoint,
    required bool isArchived,
    required int sortOrder,
  }) = _Category;
}
