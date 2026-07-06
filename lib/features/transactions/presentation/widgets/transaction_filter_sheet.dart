import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../data/database/tables/enums.dart';
import '../../../../data/models/category.dart';
import '../../../../data/models/transaction_filter.dart';
import '../../../../data/models/wallet.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../categories/application/categories_providers.dart';
import '../../../shared/entity_labels.dart';
import '../../../wallets/application/wallets_providers.dart';
import '../../application/transactions_providers.dart';

/// Opens the List-scope filter as a Material 3 modal bottom sheet. Changes are
/// applied live to [TransactionListFilter] (the standalone List scope), so the
/// list narrows behind the sheet as the user tweaks predicates.
Future<void> showTransactionFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _TransactionFilterSheet(),
  );
}

class _TransactionFilterSheet extends ConsumerStatefulWidget {
  const _TransactionFilterSheet();

  @override
  ConsumerState<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<_TransactionFilterSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(transactionListFilterProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TransactionListFilter get _notifier =>
      ref.read(transactionListFilterProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final TransactionFilter filter = ref.watch(transactionListFilterProvider);
    final List<Wallet> wallets =
        ref.watch(allWalletsProvider).asData?.value ?? const <Wallet>[];
    final List<Category> categories = ref
        .watch(visibleCategoriesProvider)
        .where((Category c) => !c.isArchived)
        .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.filterTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: filter.isActive
                      ? () {
                          _notifier.reset();
                          _searchController.clear();
                        }
                      : null,
                  child: Text(l10n.filterReset),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ----- Search -----
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.filterSearchLabel,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _notifier.setSearch,
            ),
            const SizedBox(height: AppSpacing.lg),

            // NB: the date range is no longer a filter facet — it is driven by
            // the always-on List period control on the dashboard (§C.3).

            // ----- Type -----
            _SectionLabel(l10n.filterTypeLabel),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                _ChoiceChip(
                  label: l10n.filterAll,
                  selected: filter.type == null,
                  onSelected: () => _notifier.setType(null),
                ),
                for (final TransactionType t in <TransactionType>[
                  TransactionType.income,
                  TransactionType.expense,
                  TransactionType.transfer,
                ])
                  _ChoiceChip(
                    label: transactionTypeLabel(l10n, t),
                    selected: filter.type == t,
                    onSelected: () => _notifier.setType(t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Status -----
            _SectionLabel(l10n.filterStatusLabel),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                _ChoiceChip(
                  label: l10n.filterAll,
                  selected: filter.status == null,
                  onSelected: () => _notifier.setStatus(null),
                ),
                for (final TransactionStatus s in TransactionStatus.values)
                  _ChoiceChip(
                    label: transactionStatusLabel(l10n, s),
                    selected: filter.status == s,
                    onSelected: () => _notifier.setStatus(s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Wallets (empty selection = ALL) -----
            _SectionLabel(l10n.filterWalletsLabel),
            const SizedBox(height: AppSpacing.xs),
            if (wallets.isEmpty)
              Text(l10n.filterNoWallets, style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final Wallet w in wallets)
                    FilterChip(
                      label: Text('${w.name} (${w.currencyCode})'),
                      selected: filter.walletIds.contains(w.id),
                      onSelected: (_) => _notifier.setWallets(
                        _toggled(filter.walletIds, w.id),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Categories (empty selection = ALL) -----
            _SectionLabel(l10n.filterCategoriesLabel),
            const SizedBox(height: AppSpacing.xs),
            if (categories.isEmpty)
              Text(l10n.filterNoCategories, style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final Category c in categories)
                    FilterChip(
                      label: Text(c.name),
                      selected: filter.categoryIds.contains(c.id),
                      onSelected: (_) => _notifier.setCategories(
                        _toggled(filter.categoryIds, c.id),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.filterApply),
            ),
          ],
        );
      },
    );
  }

  static Set<int> _toggled(Set<int> ids, int id) {
    final Set<int> next = Set<int>.of(ids);
    if (!next.add(id)) {
      next.remove(id);
    }
    return next;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
