import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/undo/optimistic_overlay.dart';
import '../../../core/undo/pending_action_queue.dart';
import '../../../core/undo/undoable_action.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';

part 'categories_providers.g.dart';

/// A parent category with its (depth-1) children, for the tree UI.
///
/// Only one level of nesting exists (a parent cannot itself have a parent), so
/// this flat parent→children shape captures the whole hierarchy. A [parent] with
/// a `null` [Category] models orphan children whose parent is hidden/archived.
class CategoryGroup {
  const CategoryGroup({required this.parent, required this.children});

  /// The parent category, or `null` for orphaned children rendered top-level.
  final Category? parent;

  /// Child categories under [parent], in `sortOrder`.
  final List<Category> children;
}

/// Raw reactive category stream from the repository (all types, all archive
/// states), ordered by `sortOrder`.
@riverpod
Stream<List<Category>> categoriesStream(Ref ref) =>
    ref.watch(categoryRepositoryProvider).watchCategories();

/// Categories as the user should SEE them = DB stream with the pending-undo
/// overlay applied (a queued delete disappears; a queued update shows its new
/// value). Recomputes when either the stream or the queue changes.
@riverpod
List<Category> visibleCategories(Ref ref) {
  final List<Category> base =
      ref.watch(categoriesStreamProvider).asData?.value ?? const <Category>[];
  final List<PendingEntry> queue = ref.watch(pendingActionQueueProvider);
  return applyOverlay<Category>(
    base: base,
    queue: queue,
    refOf: (Category c) => EntityRef(UndoEntityType.category, c.id),
  );
}

/// Non-archived categories of [type] as a flat list, for the transaction-form
/// picker (PROJECT_PLAN Phase 5). Archived categories are hidden from pickers
/// but still render on historical rows.
@riverpod
List<Category> categoriesForPicker(Ref ref, CategoryType type) {
  return ref
      .watch(visibleCategoriesProvider)
      .where((Category c) => c.type == type && !c.isArchived)
      .toList(growable: false);
}

/// The [type] categories structured into parent→children [CategoryGroup]s for
/// the management tree. When [includeArchived] is false, archived categories are
/// dropped; a non-archived child whose parent was dropped is surfaced as an
/// orphan group (parent == null) so it never silently disappears.
@riverpod
List<CategoryGroup> categoryGroups(
  Ref ref,
  CategoryType type, {
  bool includeArchived = false,
}) {
  final List<Category> all = ref
      .watch(visibleCategoriesProvider)
      .where((Category c) => c.type == type)
      .where((Category c) => includeArchived || !c.isArchived)
      .toList(growable: false);

  final List<Category> parents = all
      .where((Category c) => c.parentId == null)
      .toList(growable: false);
  final Set<int> parentIds = parents.map((Category c) => c.id).toSet();

  List<Category> childrenOf(int parentId) =>
      all.where((Category c) => c.parentId == parentId).toList(growable: false);

  final List<CategoryGroup> groups = <CategoryGroup>[
    for (final Category parent in parents)
      CategoryGroup(parent: parent, children: childrenOf(parent.id)),
  ];

  // Children whose parent is not in the visible set (e.g. an archived parent
  // hidden by the toggle) become an orphan group so they stay reachable.
  final List<Category> orphans = all
      .where(
        (Category c) => c.parentId != null && !parentIds.contains(c.parentId),
      )
      .toList(growable: false);
  if (orphans.isNotEmpty) {
    groups.add(CategoryGroup(parent: null, children: orphans));
  }

  return groups;
}
