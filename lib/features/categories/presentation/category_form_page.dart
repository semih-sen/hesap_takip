import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/appearance.dart';
import '../../shared/entity_labels.dart';
import '../application/categories_providers.dart';

/// Create/edit form for a [Category]. A null [category] means create.
///
/// Edits are saved immediately through the repository (a reversible, non-
/// destructive change); only DELETE is routed through the undo queue.
///
/// Integrity rules enforced here (PROJECT_PLAN Phase 4):
/// - A child MUST share its parent's [CategoryType]; selecting a parent forces
///   and locks the type to the parent's.
/// - Only depth-1 nesting: a category that already has children cannot itself
///   become a child, and a parent option is always a top-level category.
/// - On edit, the type of an already-referenced category cannot be flipped.
class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, this.category, this.initialType});

  final Category? category;

  /// Preselected type for a NEW category (e.g. the active tab). Ignored on edit.
  final CategoryType? initialType;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryType _type;
  int? _parentId;
  late int _colorValue;
  late int _iconCodePoint;
  bool _saving = false;

  /// True once we know the edited category is referenced (locks the type).
  bool _referenced = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final Category? c = widget.category;
    _nameController = TextEditingController(text: c?.name ?? '');
    _type = c?.type ?? widget.initialType ?? CategoryType.expense;
    _parentId = c?.parentId;
    _colorValue = c?.colorValue ?? Appearance.colors.first;
    _iconCodePoint =
        c?.iconCodePoint ?? Appearance.categoryIcons.first.codePoint;
    if (_isEdit) {
      _loadReferenced();
    }
  }

  Future<void> _loadReferenced() async {
    final bool referenced = await ref
        .read(categoryRepositoryProvider)
        .isReferenced(widget.category!.id);
    if (mounted) {
      setState(() => _referenced = referenced);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Whether the edited category already has children (so it cannot itself be
  /// nested under a parent — depth-1 rule).
  bool _hasChildren(List<Category> all) =>
      _isEdit && all.any((Category c) => c.parentId == widget.category!.id);

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _saving = true);
    final CategoryRepository repo = ref.read(categoryRepositoryProvider);
    final String name = _nameController.text.trim();

    if (_isEdit) {
      await repo.updateCategory(
        widget.category!.copyWith(
          name: name,
          type: _type,
          parentId: _parentId,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
        ),
      );
    } else {
      await repo.createCategory(
        Category(
          id: 0,
          name: name,
          type: _type,
          parentId: _parentId,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          isArchived: false,
          sortOrder: 0,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Category> all = ref.watch(visibleCategoriesProvider);

    final bool hasChildren = _hasChildren(all);
    // Candidate parents: top-level, same type, non-archived, not this category.
    final List<Category> parentOptions = all
        .where(
          (Category c) =>
              c.parentId == null &&
              c.type == _type &&
              !c.isArchived &&
              c.id != widget.category?.id,
        )
        .toList(growable: false);

    // The type is locked when a parent is chosen (child follows parent) or when
    // editing an already-referenced category.
    final bool typeLocked = _parentId != null || _referenced;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.categoryEdit : l10n.categoryAdd),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: l10n.categoryNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                    ? l10n.validationRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.categoryTypeLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<CategoryType>(
                segments: <ButtonSegment<CategoryType>>[
                  ButtonSegment<CategoryType>(
                    value: CategoryType.income,
                    label: Text(categoryTypeLabel(l10n, CategoryType.income)),
                    icon: const Icon(Icons.south_west),
                  ),
                  ButtonSegment<CategoryType>(
                    value: CategoryType.expense,
                    label: Text(categoryTypeLabel(l10n, CategoryType.expense)),
                    icon: const Icon(Icons.north_east),
                  ),
                ],
                selected: <CategoryType>{_type},
                onSelectionChanged: typeLocked
                    ? null
                    : (Set<CategoryType> selection) {
                        setState(() {
                          _type = selection.first;
                          // Parent must share the type; drop an incompatible one.
                          _parentId = null;
                        });
                      },
              ),
              if (_referenced)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.categoryTypeLockedHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<int?>(
                initialValue: _parentId,
                decoration: InputDecoration(
                  labelText: l10n.categoryParentLabel,
                  border: const OutlineInputBorder(),
                  helperText: hasChildren
                      ? l10n.categoryParentDisabledHint
                      : l10n.categoryParentHint,
                  helperMaxLines: 2,
                ),
                items: <DropdownMenuItem<int?>>[
                  DropdownMenuItem<int?>(child: Text(l10n.categoryParentNone)),
                  for (final Category parent in parentOptions)
                    DropdownMenuItem<int?>(
                      value: parent.id,
                      child: Text(parent.name),
                    ),
                ],
                // A category with children can't be nested (depth-1 rule).
                onChanged: hasChildren
                    ? null
                    : (int? value) => setState(() => _parentId = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.colorLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              ColorPickerRow(
                selected: _colorValue,
                onSelected: (int argb) => setState(() => _colorValue = argb),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.iconLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              IconPickerRow(
                icons: Appearance.categoryIcons,
                selected: _iconCodePoint,
                onSelected: (int cp) => setState(() => _iconCodePoint = cp),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
