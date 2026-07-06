import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/amount_parsing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../core/date/app_date.dart';
import '../../../../data/database/tables/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/transactions_providers.dart';
import '../../services/settlement_service.dart';

/// Opens the settle sheet for the pending [row], applies the settlement, then
/// shows an undo SnackBar (§5.2–5.3). `P == remaining` fully settles the item;
/// `P < remaining` partially settles it (shrinks the parent, spawns a completed
/// child). "Geri Al" reverses the exact operation.
Future<void> showSettleSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionListRow row,
) async {
  final CurrencyService currency = ref.read(currencyServiceProvider);
  final _SettleInput? input = await showModalBottomSheet<_SettleInput>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SettleSheet(row: row, currency: currency),
  );
  if (input == null || !context.mounted) {
    return;
  }
  final AppLocalizations l10n = AppLocalizations.of(context);
  final SettlementService service = ref.read(settlementServiceProvider);
  final SettlementOutcome outcome;
  try {
    outcome = await service.settle(
      transactionId: row.id,
      paymentAmountMinor: input.amountMinor,
      paymentDate: input.date,
    );
  } on SettlementFailure {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final String message = row.type == TransactionType.income
      ? l10n.settledIncome
      : l10n.settledExpense;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () {
            if (outcome.wasFull) {
              service.reopen(
                transactionId: outcome.parentId,
                originalValueDate: outcome.originalValueDate!,
              );
            } else {
              service.reverseSettlementChild(outcome.childId!);
            }
          },
        ),
      ),
    );
}

/// The user's confirmed input from the settle sheet.
class _SettleInput {
  const _SettleInput({required this.amountMinor, required this.date});
  final int amountMinor;
  final DateTime date;
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.row, required this.currency});

  final TransactionListRow row;
  final CurrencyService currency;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  DateTime _date = AppDate.today();



  @override
  void initState() {
    super.initState();
    // Prefill with the full remaining, rendered in the Turkish decimal form the
    // shared parser expects (',' as the decimal separator).
    final Decimal major = widget.currency.fromMinor(
      widget.row.amountMinor,
      widget.row.currencyCode,
    );
    _amountController = TextEditingController(
      text: major.toString().replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _date = AppDate.dateOnly(picked));
    }
  }

  void _confirm() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final int amountMinor = widget.currency.toMinor(
      parseTurkishAmount(_amountController.text) ?? Decimal.zero,
      widget.row.currencyCode,
    );
    Navigator.of(context).pop(_SettleInput(amountMinor: amountMinor, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isIncome = widget.row.type == TransactionType.income;
    final String title = isIncome
        ? l10n.settleCollectTitle
        : l10n.settlePayTitle;
    final String code = widget.row.currencyCode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.settleRemaining(
                    widget.currency.format(widget.row.amountMinor, code),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${l10n.settleAmountLabel} ($code)',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final Decimal? parsed = parseTurkishAmount(value ?? '');
                    if (parsed == null || parsed <= Decimal.zero) {
                      return l10n.validationInvalidAmount;
                    }
                    final int minor = widget.currency.toMinor(parsed, code);
                    if (minor > widget.row.amountMinor) {
                      return l10n.validationOverpayment(
                        widget.currency.format(widget.row.amountMinor, code),
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${l10n.settleDateLabel}: '
                    '${DateFormat('d MMMM yyyy', 'tr_TR').format(_date)}',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: Text(title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
