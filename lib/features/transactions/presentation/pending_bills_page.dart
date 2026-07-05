import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../data/database/tables/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/entity_labels.dart';
import '../application/bills_providers.dart';
import 'bill_detail_page.dart';
import 'transaction_form_page.dart';

/// Pending bills & receivables (Phase 9 §B.6.1): the open parent bills split
/// into **Borçlar** (expense) and **Alacaklar** (income), each row showing
/// planned / settled / remaining and a slim progress bar. A FAB opens the
/// transaction form in bill-creation mode.
class PendingBillsPage extends ConsumerWidget {
  const PendingBillsPage({super.key});

  static const CurrencyService _currency = CurrencyService();

  void _addBill(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TransactionFormPage(billMode: true),
      ),
    );
  }

  void _open(BuildContext context, BillRow bill) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BillDetailPage(billId: bill.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<BillRow> bills = ref.watch(visibleBillsProvider);
    final List<BillRow> debts = bills
        .where((BillRow b) => b.type == TransactionType.expense)
        .toList(growable: false);
    final List<BillRow> receivables = bills
        .where((BillRow b) => b.type == TransactionType.income)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBill(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.billAdd),
      ),
      body: SafeArea(
        child: bills.isEmpty
            ? _Empty(message: l10n.billsEmpty)
            : ListView(
                padding: AppSpacing.screenPadding,
                children: <Widget>[
                  if (debts.isNotEmpty) ...<Widget>[
                    _SectionHeader(label: l10n.billsSectionDebts),
                    for (final BillRow b in debts)
                      _BillCard(
                        key: ValueKey<int>(b.id),
                        bill: b,
                        currency: _currency,
                        onTap: () => _open(context, b),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (receivables.isNotEmpty) ...<Widget>[
                    _SectionHeader(label: l10n.billsSectionReceivables),
                    for (final BillRow b in receivables)
                      _BillCard(
                        key: ValueKey<int>(b.id),
                        bill: b,
                        currency: _currency,
                        onTap: () => _open(context, b),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: semantic.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    super.key,
    required this.bill,
    required this.currency,
    required this.onTap,
  });

  final BillRow bill;
  final CurrencyService currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final Color accent = bill.type == TransactionType.income
        ? semantic.income
        : semantic.expense;
    final String title = bill.title ?? transactionTypeLabel(l10n, bill.type);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.billRemaining(
                      currency.format(bill.remainingMinor, bill.currencyCode),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: LinearProgressIndicator(
                  value: bill.progress,
                  minHeight: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.billProgress(
                  currency.format(bill.settledMinor, bill.currencyCode),
                  currency.format(bill.plannedMinor, bill.currencyCode),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

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
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
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
