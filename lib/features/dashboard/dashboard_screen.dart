import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../transactions/application/transactions_providers.dart';
import '../transactions/presentation/transaction_form_page.dart';
import '../transactions/presentation/widgets/transaction_filter_sheet.dart';
import '../transactions/presentation/widgets/transaction_list_view.dart';

/// Dashboard (Phase 6): hosts the date-grouped, filterable transaction list
/// across all wallets with a FAB to add and a filter entry point (badged when
/// the List filter is active). Tap a row to edit; long-press to delete via the
/// undo queue. The Summary card and Summary scope arrive in Phase 7.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TransactionFormPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool filterActive = ref.watch(
      transactionListFilterProvider.select((filter) => filter.isActive),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.filterTitle,
            onPressed: () => showTransactionFilterSheet(context),
            icon: filterActive
                ? Badge(smallSize: 8, child: const Icon(Icons.filter_list))
                : const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.transactionAdd),
      ),
      body: const SafeArea(child: TransactionListView()),
    );
  }
}
