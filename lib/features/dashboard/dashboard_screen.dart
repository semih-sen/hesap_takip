import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../transactions/application/transactions_providers.dart';
import '../transactions/presentation/pending_bills_page.dart';
import '../transactions/presentation/transaction_form_page.dart';
import '../transactions/presentation/transfer_form_page.dart';
import '../transactions/presentation/widgets/transaction_filter_sheet.dart';
import '../transactions/presentation/widgets/transaction_list_view.dart';
import 'widgets/summary_account_selector.dart';
import 'widgets/summary_card.dart';
import 'widgets/summary_period_switcher.dart';

/// Dashboard (Phase 6 + 7): the Summary section (period switcher + base-currency
/// income/expense/net card + account selector, all driven by the Summary scope)
/// sits ABOVE the date-grouped, filterable transaction list. The two scopes are
/// independent — changing the summary period/accounts never touches the List
/// filter, and vice-versa (PROJECT_PLAN §9, the two-scope rule). A FAB adds; the
/// app-bar action opens the List filter (badged when active).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TransactionFormPage()),
    );
  }

  void _addTransfer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TransferFormPage()),
    );
  }

  void _openBills(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PendingBillsPage()),
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
            tooltip: l10n.billsTitle,
            onPressed: () => _openBills(context),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: l10n.transferAdd,
            onPressed: () => _addTransfer(context),
            icon: const Icon(Icons.swap_horiz),
          ),
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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const <Widget>[
                  SummaryPeriodSwitcher(),
                  SizedBox(height: AppSpacing.sm),
                  SummaryCard(),
                  SizedBox(height: AppSpacing.sm),
                  SummaryAccountSelector(),
                ],
              ),
            ),
            const Expanded(child: TransactionListView()),
          ],
        ),
      ),
    );
  }
}
