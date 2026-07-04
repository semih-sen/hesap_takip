import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/undo/entity_actions.dart';
import '../../core/undo/undo_service.dart';
import '../../data/database/tables/enums.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/appearance.dart';
import '../shared/undo_snackbar.dart';
import 'application/categories_providers.dart';
import 'presentation/category_form_page.dart';

/// Categories home (Phase 4): hierarchical income/expense categories with full
/// CRUD, archive, and undo-routed delete. Two tabs separate income (Gelir) from
/// expense (Gider); an app-bar toggle reveals archived categories.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _showArchived = false;

  void _add(BuildContext context, CategoryType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryFormPage(initialType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Category>> stream = ref.watch(
      categoriesStreamProvider,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.categoriesTitle),
          actions: <Widget>[
            IconButton(
              tooltip: _showArchived
                  ? l10n.categoryHideArchived
                  : l10n.categoryShowArchived,
              icon: Icon(
                _showArchived ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showArchived = !_showArchived),
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.categoryTypeIncome),
              Tab(text: l10n.categoryTypeExpense),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (BuildContext context) {
            final CategoryType type =
                DefaultTabController.of(context).index == 0
                ? CategoryType.income
                : CategoryType.expense;
            return FloatingActionButton.extended(
              onPressed: () => _add(context, type),
              icon: const Icon(Icons.add),
              label: Text(l10n.categoryAdd),
            );
          },
        ),
        body: stream.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _ErrorState(
            message: l10n.errorGeneric,
            onRetry: () => ref.invalidate(categoriesStreamProvider),
            retryLabel: l10n.actionRetry,
          ),
          data: (_) => TabBarView(
            children: <Widget>[
              _CategoryTree(
                type: CategoryType.income,
                showArchived: _showArchived,
              ),
              _CategoryTree(
                type: CategoryType.expense,
                showArchived: _showArchived,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab's parent→children tree for [type].
class _CategoryTree extends ConsumerWidget {
  const _CategoryTree({required this.type, required this.showArchived});

  final CategoryType type;
  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<CategoryGroup> groups = ref.watch(
      categoryGroupsProvider(type, includeArchived: showArchived),
    );
    if (groups.isEmpty) {
      return _EmptyState(
        title: l10n.categoriesEmptyTitle,
        message: l10n.categoriesEmptyMessage,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xxl * 2,
      ),
      children: <Widget>[
        for (final CategoryGroup group in groups) ...<Widget>[
          if (group.parent != null)
            _CategoryRow(
              key: ValueKey<int>(group.parent!.id),
              category: group.parent!,
            ),
          for (final Category child in group.children)
            _CategoryRow(
              key: ValueKey<int>(child.id),
              category: child,
              indented: true,
            ),
        ],
      ],
    );
  }
}

/// A bespoke category row: color dot + icon, name, optional archived badge, and
/// an overflow menu (edit / archive / delete).
class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    this.indented = false,
  });

  final Category category;
  final bool indented;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeleteCategoryAction action = DeleteCategoryAction(
      category: category,
      label: l10n.categoryDeleted(category.name),
    );
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(action);
    if (!context.mounted) {
      return;
    }
    if (pendingId == null) {
      // Has children or is referenced by history → archive instead of delete.
      showInfoSnackBar(context, l10n.categoryDeleteBlocked);
      return;
    }
    showUndoSnackBar(
      context,
      ref,
      pendingId: pendingId,
      message: l10n.categoryDeleted(category.name),
    );
  }

  Future<void> _toggleArchive(WidgetRef ref) async {
    final CategoryRepository repo = ref.read(categoryRepositoryProvider);
    await repo.updateCategory(
      category.copyWith(isArchived: !category.isArchived),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryFormPage(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color color = Color(category.colorValue);

    return Opacity(
      opacity: category.isArchived ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.only(
          left: indented ? AppSpacing.xxl : AppSpacing.lg,
          right: AppSpacing.sm,
        ),
        leading: _CategoryLeading(color: color, category: category),
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(category.name, overflow: TextOverflow.ellipsis),
            ),
            if (category.isArchived) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.archivedBadge,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<_CategoryMenu>(
          onSelected: (_CategoryMenu value) {
            switch (value) {
              case _CategoryMenu.edit:
                _edit(context);
              case _CategoryMenu.archive:
                _toggleArchive(ref);
              case _CategoryMenu.delete:
                _delete(context, ref);
            }
          },
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<_CategoryMenu>>[
                PopupMenuItem<_CategoryMenu>(
                  value: _CategoryMenu.edit,
                  child: Text(l10n.actionEdit),
                ),
                PopupMenuItem<_CategoryMenu>(
                  value: _CategoryMenu.archive,
                  child: Text(
                    category.isArchived
                        ? l10n.actionUnarchive
                        : l10n.actionArchive,
                  ),
                ),
                PopupMenuItem<_CategoryMenu>(
                  value: _CategoryMenu.delete,
                  child: Text(l10n.actionDelete),
                ),
              ],
        ),
      ),
    );
  }
}

class _CategoryLeading extends StatelessWidget {
  const _CategoryLeading({required this.color, required this.category});

  final Color color;
  final Category category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Appearance.iconFromCodePoint(category.iconCodePoint),
            color: color,
            size: 22,
          ),
        ],
      ),
    );
  }
}

enum _CategoryMenu { edit, archive, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.category_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 56, color: AppColors.expense),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
