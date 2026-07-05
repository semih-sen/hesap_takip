import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/undo/entity_actions.dart';
import '../../../core/undo/undo_service.dart';
import '../../../data/database/tables/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/entity_labels.dart';
import '../../shared/undo_snackbar.dart';
import '../application/bills_providers.dart';
import 'apply_payment_page.dart';

/// One bill's detail (Phase 9 §B.6.3): a progress header, the child-payment
/// history (each reversible through the delayed-execution Undo flow), an
/// "Ödeme ekle" action, and a cascade delete guarded by a confirm dialog.
class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({super.key, required this.billId});

  final int billId;

  static const CurrencyService _currency = CurrencyService();

  Future<void> _addPayment(BuildContext context, BillRow bill) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ApplyPaymentPage(bill: bill)),
    );
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    PaymentRow child,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label = l10n.paymentReversed;
    final String? pendingId = await ref.read(undoServiceProvider).enqueue(
      ReversePaymentAction(
        childId: child.id,
        parentId: child.parentId,
        contribMinor: child.settledContribMinor,
        label: label,
      ),
    );
    if (pendingId == null || !context.mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
  }

  Future<void> _deleteBill(
    BuildContext context,
    WidgetRef ref,
    BillRow bill,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.billDeleteTitle),
            content: Text(l10n.billDeleteMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    final String label = l10n.billDeleted;
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(DeleteBillAction(parentId: bill.id, label: label));
    if (pendingId == null || !context.mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
    // The bill is gone from the visible list; leave the detail screen.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BillRow? bill = ref.watch(billProvider(billId));
    final List<PaymentRow> children = ref.watch(
      visibleBillChildrenProvider(billId),
    );

    if (bill == null) {
      // The bill was deleted while open — pop on the next frame.
      return Scaffold(
        appBar: AppBar(title: Text(l10n.billDetailTitle)),
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billDetailTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.actionDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteBill(context, ref, bill),
          ),
        ],
      ),
      floatingActionButton: bill.isFullySettled
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addPayment(context, bill),
              icon: const Icon(Icons.add),
              label: Text(l10n.paymentAdd),
            ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: <Widget>[
            _BillHeader(bill: bill, currency: _currency),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.paymentHistoryTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (children.isEmpty)
              Text(
                l10n.paymentHistoryEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final PaymentRow child in children)
                _PaymentTile(
                  key: ValueKey<int>(child.id),
                  payment: child,
                  currency: _currency,
                  onReverse: () => _reverse(context, ref, child),
                ),
          ],
        ),
      ),
    );
  }
}

/// The progress header: title, remaining, planned/settled and a progress bar.
class _BillHeader extends StatelessWidget {
  const _BillHeader({required this.bill, required this.currency});

  final BillRow bill;
  final CurrencyService currency;

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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Text(
                  currency.format(bill.remainingMinor, bill.currencyCode),
                  style: theme.textTheme.titleMedium?.copyWith(
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
                minHeight: 6,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l10n.billProgress(
                    currency.format(bill.settledMinor, bill.currencyCode),
                    currency.format(bill.plannedMinor, bill.currencyCode),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy', 'tr_TR').format(bill.valueDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single child-payment row; long-press reverses it via the Undo flow.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    super.key,
    required this.payment,
    required this.currency,
    required this.onReverse,
  });

  final PaymentRow payment;
  final CurrencyService currency;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;
    final String date = DateFormat(
      'd MMM yyyy',
      'tr_TR',
    ).format(payment.valueDate);
    final String? note = payment.note?.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onLongPress: onReverse,
      title: Text(
        currency.format(payment.amountMinor, payment.currencyCode),
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        note == null || note.isEmpty ? date : '$date · $note',
        style: theme.textTheme.bodySmall?.copyWith(color: semantic.textMuted),
      ),
      trailing: IconButton(
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        icon: const Icon(Icons.undo),
        onPressed: onReverse,
      ),
    );
  }
}
