import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/amount_parsing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../wallets/application/wallets_providers.dart';
import '../application/bills_providers.dart';
import '../services/partial_payment_service.dart';

/// Applies a payment against the pending bill [bill] (Phase 9 §B.6.2). The
/// amount is entered in the SOURCE wallet's currency; when that differs from the
/// bill's currency a `rateToParentCurrency` field appears, and when it differs
/// from the base currency a `rateToBase` field appears — both prefilled from the
/// rate cache and editable. Overpayment is offered as "cap to remaining" or
/// "allow overpayment".
class ApplyPaymentPage extends ConsumerStatefulWidget {
  const ApplyPaymentPage({super.key, required this.bill});

  final BillRow bill;

  @override
  ConsumerState<ApplyPaymentPage> createState() => _ApplyPaymentPageState();
}

class _ApplyPaymentPageState extends ConsumerState<ApplyPaymentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateToParentController = TextEditingController();
  final TextEditingController _rateToBaseController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int? _walletId;
  DateTime _valueDate = AppDate.today();
  bool _saving = false;

  static const CurrencyService _currency = CurrencyService();

  @override
  void dispose() {
    _amountController.dispose();
    _rateToParentController.dispose();
    _rateToBaseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Wallet? _selectedWallet(List<Wallet> wallets) {
    for (final Wallet w in wallets) {
      if (w.id == _walletId) {
        return w;
      }
    }
    return null;
  }

  Future<void> _onWalletChanged(int? id, String base) async {
    setState(() => _walletId = id);
    final List<Wallet> wallets =
        ref.read(allWalletsProvider).asData?.value ?? const <Wallet>[];
    final Wallet? wallet = _selectedWallet(wallets);
    if (wallet == null) {
      return;
    }
    await _prefillRates(wallet, base);
  }

  Future<Decimal> _cachedRate(String from, String to) async {
    final entry = await ref
        .read(exchangeRateRepositoryProvider)
        .latestRate(from, to, onOrBefore: _valueDate);
    return entry?.rate ?? Decimal.one;
  }

  Future<void> _prefillRates(Wallet wallet, String base) async {
    final String source = wallet.currencyCode;
    _rateToParentController.text = source != widget.bill.currencyCode
        ? (await _cachedRate(source, widget.bill.currencyCode)).toString()
        : '';
    _rateToBaseController.text = source != base
        ? (await _cachedRate(source, base)).toString()
        : '';
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _valueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _valueDate = AppDate.dateOnly(picked));
    }
  }

  Future<void> _save(String base, List<Wallet> wallets) async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final Wallet? wallet = _selectedWallet(wallets);
    if (wallet == null) {
      return;
    }
    setState(() => _saving = true);
    final String source = wallet.currencyCode;
    final int amountMinor = _currency.toMinor(
      parseTurkishAmount(_amountController.text) ?? Decimal.zero,
      source,
    );
    final Decimal rateToParent = source == widget.bill.currencyCode
        ? Decimal.one
        : (parseTurkishAmount(_rateToParentController.text) ?? Decimal.one);
    final Decimal rateToBase = source == base
        ? Decimal.one
        : (parseTurkishAmount(_rateToBaseController.text) ?? Decimal.one);

    final bool ok = await _submit(
      sourceWalletId: wallet.id,
      amountMinor: amountMinor,
      rateToParent: rateToParent,
      rateToBase: rateToBase,
      allowOverpayment: false,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  /// Runs [PartialPaymentService.applyPayment], handling [OverpaymentFailure] by
  /// prompting the user to cap or allow. Returns true when a payment was written.
  Future<bool> _submit({
    required int sourceWalletId,
    required int amountMinor,
    required Decimal rateToParent,
    required Decimal rateToBase,
    required bool allowOverpayment,
  }) async {
    final PartialPaymentService service = ref.read(
      partialPaymentServiceProvider,
    );
    try {
      await service.applyPayment(
        parentId: widget.bill.id,
        sourceWalletId: sourceWalletId,
        paymentAmountMinor: amountMinor,
        rateToParentCurrency: rateToParent,
        rateToBase: rateToBase,
        valueDate: _valueDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        allowOverpayment: allowOverpayment,
      );
      return true;
    } on OverpaymentFailure catch (failure) {
      if (!mounted) {
        return false;
      }
      final _OverpaymentChoice? choice = await _askOverpayment(failure);
      if (choice == null) {
        return false;
      }
      if (choice == _OverpaymentChoice.allow) {
        return _submit(
          sourceWalletId: sourceWalletId,
          amountMinor: amountMinor,
          rateToParent: rateToParent,
          rateToBase: rateToBase,
          allowOverpayment: true,
        );
      }
      // Cap to the remaining balance (expressed in the source currency). Same
      // -currency is exact; cross-currency inverts the entered rate, and we set
      // allowOverpayment so a residual rounding cent can never re-trigger.
      final int cappedSource = _sourceAmountForRemaining(
        failure.remainingMinor,
        sourceWalletId,
        rateToParent,
      );
      if (cappedSource <= 0) {
        return false;
      }
      return _submit(
        sourceWalletId: sourceWalletId,
        amountMinor: cappedSource,
        rateToParent: rateToParent,
        rateToBase: rateToBase,
        allowOverpayment: true,
      );
    }
  }

  /// The source-currency amount whose conversion to the bill currency equals
  /// [remainingParentMinor]. Exact when the currencies match; otherwise the
  /// entered [rateToParent] is inverted.
  int _sourceAmountForRemaining(
    int remainingParentMinor,
    int sourceWalletId,
    Decimal rateToParent,
  ) {
    final List<Wallet> wallets =
        ref.read(allWalletsProvider).asData?.value ?? const <Wallet>[];
    final Wallet? wallet = _selectedWallet(wallets);
    if (wallet == null) {
      return 0;
    }
    if (wallet.currencyCode == widget.bill.currencyCode) {
      return remainingParentMinor;
    }
    final Decimal remainingMajor = _currency.fromMinor(
      remainingParentMinor,
      widget.bill.currencyCode,
    );
    // Invert the entered rate to express the remaining in the source currency.
    final Decimal sourceMajor = (remainingMajor / rateToParent).toDecimal(
      scaleOnInfinitePrecision: 12,
    );
    return _currency.toMinor(sourceMajor, wallet.currencyCode);
  }

  Future<_OverpaymentChoice?> _askOverpayment(OverpaymentFailure failure) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String parentCode = widget.bill.currencyCode;
    return showDialog<_OverpaymentChoice>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.overpaymentTitle),
        content: Text(
          l10n.overpaymentMessage(
            _currency.format(failure.attemptedMinor, parentCode),
            _currency.format(failure.remainingMinor, parentCode),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_OverpaymentChoice.cap),
            child: Text(l10n.overpaymentCap),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_OverpaymentChoice.allow),
            child: Text(l10n.overpaymentAllow),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String base = ref.watch(baseCurrencyProvider);
    final AsyncValue<List<Wallet>> walletsAsync = ref.watch(allWalletsProvider);
    final BillRow bill = ref.watch(billProvider(widget.bill.id)) ?? widget.bill;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentAdd)),
      body: SafeArea(
        child: walletsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) =>
              Center(child: Text(l10n.errorGeneric)),
          data: (List<Wallet> wallets) =>
              _buildForm(context, l10n, base, wallets, bill),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    String base,
    List<Wallet> wallets,
    BillRow bill,
  ) {
    final Wallet? wallet = _selectedWallet(wallets);
    final String? source = wallet?.currencyCode;
    final bool needsParentRate =
        source != null && source != bill.currencyCode;
    final bool needsBaseRate = source != null && source != base;

    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          _RemainingBanner(bill: bill, currency: _currency),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            initialValue: _walletId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.paymentSourceWalletLabel,
              border: const OutlineInputBorder(),
            ),
            items: wallets
                .map(
                  (Wallet w) => DropdownMenuItem<int>(
                    value: w.id,
                    child: Text(
                      '${w.name} (${w.currencyCode})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            validator: (int? value) =>
                value == null ? l10n.validationRequired : null,
            onChanged: (int? value) => _onWalletChanged(value, base),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: source == null
                  ? l10n.paymentAmountLabel
                  : '${l10n.paymentAmountLabel} ($source)',
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) {
              final Decimal? parsed = parseTurkishAmount(value ?? '');
              if (parsed == null || parsed <= Decimal.zero) {
                return l10n.validationInvalidAmount;
              }
              return null;
            },
          ),
          if (needsParentRate) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _rateToParentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.paymentRateToParentLabel(
                  source,
                  bill.currencyCode,
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (String? value) {
                final Decimal? parsed = parseTurkishAmount(value ?? '');
                if (parsed == null || parsed <= Decimal.zero) {
                  return l10n.validationInvalidRate;
                }
                return null;
              },
            ),
          ],
          if (needsBaseRate) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _rateToBaseController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.transactionRateLabel(source, base),
                border: const OutlineInputBorder(),
              ),
              validator: (String? value) {
                final Decimal? parsed = parseTurkishAmount(value ?? '');
                if (parsed == null || parsed <= Decimal.zero) {
                  return l10n.validationInvalidRate;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              '${l10n.transactionDateLabel}: '
              '${DateFormat('d MMMM yyyy', 'tr_TR').format(_valueDate)}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: l10n.transactionNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(base, wallets),
            icon: const Icon(Icons.check),
            label: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }
}

enum _OverpaymentChoice { cap, allow }

/// A compact "remaining / planned" banner atop the payment form.
class _RemainingBanner extends StatelessWidget {
  const _RemainingBanner({required this.bill, required this.currency});

  final BillRow bill;
  final CurrencyService currency;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.billRemaining(
                currency.format(bill.remainingMinor, bill.currencyCode),
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: LinearProgressIndicator(value: bill.progress, minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.billProgress(
                currency.format(bill.settledMinor, bill.currencyCode),
                currency.format(bill.plannedMinor, bill.currencyCode),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
