import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/amount_parsing.dart';
import '../../../core/currency/currency.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/models/exchange_rate_entry.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

part 'exchange_rates_screen.g.dart';

/// Reactive list of cached exchange rates, newest `asOfDate` first.
@riverpod
Stream<List<ExchangeRateEntry>> exchangeRates(Ref ref) =>
    ref.watch(exchangeRateRepositoryProvider).watchRates();

/// Manual exchange-rate cache management (PROJECT_PLAN §11 / §E.4). Feeds the
/// rate-prefill used by the transaction/transfer forms. Delete is a simple
/// confirm dialog (a low-stakes cache entry, not ledger data — no undo).
class ExchangeRatesScreen extends ConsumerWidget {
  const ExchangeRatesScreen({super.key});

  static final DateFormat _dateFormat = DateFormat.yMMMd('tr_TR');

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ExchangeRateEntry? entry = await showModalBottomSheet<ExchangeRateEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ExchangeRateForm(),
    );
    if (entry == null || !context.mounted) {
      return;
    }
    await ref.read(exchangeRateRepositoryProvider).addRate(entry);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExchangeRateEntry entry,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.exchangeRateDeleteTitle),
            content: Text(l10n.exchangeRateDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) {
      return;
    }
    await ref.read(exchangeRateRepositoryProvider).deleteRate(entry.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<ExchangeRateEntry>> rates = ref.watch(
      exchangeRatesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exchangeRatesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.exchangeRateAdd),
      ),
      body: SafeArea(
        child: rates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) =>
              Center(child: Text(l10n.errorGeneric)),
          data: (List<ExchangeRateEntry> list) {
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: Text(
                    l10n.exchangeRatesEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final ExchangeRateEntry e = list[index];
                return ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text('${e.baseCurrency} → ${e.quoteCurrency}'),
                  subtitle: Text(_dateFormat.format(e.asOfDate)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        e.rate.toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, e),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A small add-rate form returned as an [ExchangeRateEntry] (id 0, DB-assigned).
class _ExchangeRateForm extends ConsumerStatefulWidget {
  const _ExchangeRateForm();

  @override
  ConsumerState<_ExchangeRateForm> createState() => _ExchangeRateFormState();
}

class _ExchangeRateFormState extends ConsumerState<_ExchangeRateForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _rateController = TextEditingController();

  late String _from;
  late String _to;
  DateTime _asOf = AppDate.today();
  
  @override
  void initState() {
    super.initState();
    final CurrencyService currencyService = ref.read(currencyServiceProvider);
    _from = currencyService.all.first.code;
    _to = currencyService.all.length > 1
        ? currencyService.all[1].code
        : currencyService.all.first.code;
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _asOf = AppDate.dateOnly(picked));
    }
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_from == _to) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.exchangeRateSameCurrency),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final Decimal rate =
        parseTurkishAmount(_rateController.text) ?? Decimal.one;
    Navigator.of(context).pop(
      ExchangeRateEntry(
        id: 0,
        baseCurrency: _from,
        quoteCurrency: _to,
        rate: rate,
        asOfDate: _asOf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CurrencyService currencyService = ref.read(currencyServiceProvider);
    final List<String> codes = <String>[
      for (final Currency c in currencyService.all) c.code,
    ]..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.exchangeRateAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _from,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.exchangeRateFromLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String c in codes)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _from = v ?? _from),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _to,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.exchangeRateToLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String c in codes)
                        DropdownMenuItem<String>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? v) => setState(() => _to = v ?? _to),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.exchangeRateValueLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (String? v) {
                final Decimal? parsed = parseTurkishAmount(v ?? '');
                if (parsed == null || parsed <= Decimal.zero) {
                  return l10n.validationInvalidRate;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                '${l10n.exchangeRateDateLabel}: '
                '${DateFormat.yMMMd('tr_TR').format(_asOf)}',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}
