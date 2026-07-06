import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/amount_parsing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/date/app_date.dart';
import '../../../data/models/account.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/wallet.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/balance_service.dart';
import '../services/transfer_service.dart';

/// Create/edit a two-leg transfer (PROJECT_PLAN §5.2 / Phase 8).
///
/// The amount is entered in the source wallet's currency; when the destination
/// wallet uses a different currency a rate field (prefilled from the cache) and
/// an editable destination-amount field appear. Saving goes through
/// [TransferService], which writes both legs in one atomic transaction. All
/// user-facing strings come from the ARB.
class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key, this.transferGroupId});

  /// Non-null when editing an existing transfer.
  final String? transferGroupId;

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int? _fromWalletId;
  int? _toWalletId;
  DateTime _valueDate = AppDate.today();
  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.transferGroupId != null;

  @override
  void initState() {
    super.initState();
    _fromAmountController.addListener(_recomputeTo);
    _rateController.addListener(_recomputeTo);
    if (_isEdit) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadForEdit() async {
    final TransferService service = ref.read(transferServiceProvider);
    final ({Transaction from, Transaction to})? legs =
        await service.loadTransfer(widget.transferGroupId!);
    if (legs == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _fromWalletId = legs.from.walletId;
      _toWalletId = legs.to.walletId;
      _valueDate = AppDate.dateOnly(legs.from.valueDate);
      final CurrencyService currency = ref.read(currencyServiceProvider);
      _fromAmountController.text = currency
          .fromMinor(legs.from.amount.minorUnits, legs.from.currencyCode)
          .toString();
      _toAmountController.text = currency
          .fromMinor(legs.to.amount.minorUnits, legs.to.currencyCode)
          .toString();
      _noteController.text = legs.from.note ?? '';
      _loading = false;
    });
  }

  Wallet? _walletById(List<Wallet> wallets, int? id) {
    for (final Wallet w in wallets) {
      if (w.id == id) {
        return w;
      }
    }
    return null;
  }

  /// Whether the two selected wallets use different currencies.
  bool _crossCurrency(List<Wallet> wallets) {
    final Wallet? from = _walletById(wallets, _fromWalletId);
    final Wallet? to = _walletById(wallets, _toWalletId);
    return from != null && to != null && from.currencyCode != to.currencyCode;
  }

  /// Recomputes the destination amount from `fromAmount × rate` (half-up),
  /// keeping same-currency transfers mirrored.
  void _recomputeTo() {
    final List<Wallet> wallets =
        ref.read(allWalletsProvider).asData?.value ?? const <Wallet>[];
    final Wallet? from = _walletById(wallets, _fromWalletId);
    final Wallet? to = _walletById(wallets, _toWalletId);
    if (from == null || to == null) {
      return;
    }
    final Decimal amount =
        parseTurkishAmount(_fromAmountController.text) ?? Decimal.zero;
    if (from.currencyCode == to.currencyCode) {
      _toAmountController.text = amount == Decimal.zero
          ? ''
          : amount.toString();
      return;
    }
    final Decimal rate =
        parseTurkishAmount(_rateController.text) ?? Decimal.one;
    _toAmountController.text = (amount * rate).toString();
  }

  Future<void> _onWalletChanged() async {
    // Refresh the rate suggestion + destination amount when a wallet changes.
    final List<Wallet> wallets =
        ref.read(allWalletsProvider).asData?.value ?? const <Wallet>[];
    final Wallet? from = _walletById(wallets, _fromWalletId);
    final Wallet? to = _walletById(wallets, _toWalletId);
    if (from != null && to != null && from.currencyCode != to.currencyCode) {
      final Decimal suggested = await ref
          .read(transferServiceProvider)
          .suggestRate(from.currencyCode, to.currencyCode, _valueDate);
      if (!mounted) {
        return;
      }
      _rateController.text = suggested.toString();
    } else {
      _rateController.text = '';
    }
    _recomputeTo();
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

  String _errorFor(AppLocalizations l10n, TransferValidationReason reason) =>
      switch (reason) {
        TransferValidationReason.sameWallet => l10n.transferErrorSameWallet,
        TransferValidationReason.nonPositiveAmount =>
          l10n.transferErrorNonPositive,
        TransferValidationReason.archivedWallet => l10n.transferErrorArchived,
        TransferValidationReason.missingWallet =>
          l10n.transferErrorMissingWallet,
      };

  Future<void> _save(List<Wallet> wallets) async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final Wallet? from = _walletById(wallets, _fromWalletId);
    final Wallet? to = _walletById(wallets, _toWalletId);
    if (from == null || to == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    final bool cross = from.currencyCode != to.currencyCode;
    final CurrencyService currency = ref.read(currencyServiceProvider);
    final int fromMinor = currency.toMinor(
      parseTurkishAmount(_fromAmountController.text) ?? Decimal.zero,
      from.currencyCode,
    );
    final int toMinor = cross
        ? currency.toMinor(
            parseTurkishAmount(_toAmountController.text) ?? Decimal.zero,
            to.currencyCode,
          )
        : fromMinor;
    final Decimal rate = cross
        ? (parseTurkishAmount(_rateController.text) ?? Decimal.one)
        : Decimal.one;

    try {
      final TransferService service = ref.read(transferServiceProvider);
      if (_isEdit) {
        await service.updateTransfer(
          transferGroupId: widget.transferGroupId!,
          fromWalletId: from.id,
          toWalletId: to.id,
          fromAmountMinor: fromMinor,
          toAmountMinor: toMinor,
          rate: rate,
          valueDate: _valueDate,
          note: _emptyToNull(_noteController.text),
        );
      } else {
        await service.createTransfer(
          fromWalletId: from.id,
          toWalletId: to.id,
          fromAmountMinor: fromMinor,
          toAmountMinor: toMinor,
          rate: rate,
          valueDate: _valueDate,
          note: _emptyToNull(_noteController.text),
        );
      }
    } on TransferValidationException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_errorFor(l10n, e.reason)),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Wallet>> walletsAsync = ref.watch(allWalletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.transferEdit : l10n.transferAdd),
      ),
      body: SafeArea(
        child: walletsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object _, StackTrace _) =>
              Center(child: Text(l10n.errorGeneric)),
          data: (List<Wallet> all) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<Wallet> active = all
                .where((Wallet w) => !w.isArchived)
                .toList(growable: false);
            if (active.length < 2) {
              return Center(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: Text(
                    l10n.transferNeedsTwoWallets,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _buildForm(context, l10n, active);
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    List<Wallet> wallets,
  ) {
    final bool cross = _crossCurrency(wallets);
    final Wallet? from = _walletById(wallets, _fromWalletId);
    final Wallet? to = _walletById(wallets, _toWalletId);
    final Map<int, String> accountNames = <int, String>{
      for (final Account a
          in ref.watch(accountsStreamProvider).asData?.value ??
              const <Account>[])
        a.id: a.name,
    };

    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          DropdownButtonFormField<int>(
            initialValue: _fromWalletId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.transferFromLabel),
            items: <DropdownMenuItem<int>>[
              for (final Wallet w in wallets)
                DropdownMenuItem<int>(
                  value: w.id,
                  child: _walletLabel(w, accountNames),
                ),
            ],
            validator: (int? v) => v == null ? l10n.validationRequired : null,
            onChanged: (int? v) {
              setState(() {
                _fromWalletId = v;
                if (_toWalletId == v) {
                  _toWalletId = null; // keep the two wallets distinct
                }
              });
              _onWalletChanged();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _toWalletId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.transferToLabel),
            items: <DropdownMenuItem<int>>[
              for (final Wallet w in wallets)
                DropdownMenuItem<int>(
                  value: w.id,
                  // The source wallet cannot also be the destination.
                  enabled: w.id != _fromWalletId,
                  child: _walletLabel(w, accountNames),
                ),
            ],
            validator: (int? v) {
              if (v == null) {
                return l10n.validationRequired;
              }
              if (v == _fromWalletId) {
                return l10n.transferErrorSameWallet;
              }
              return null;
            },
            onChanged: (int? v) {
              setState(() => _toWalletId = v);
              _onWalletChanged();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _fromAmountController,
            decoration: InputDecoration(
              labelText: l10n.transferFromAmountLabel,
              suffixText: from?.currencyCode,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (String? v) => _positiveAmountValidator(l10n, v),
          ),
          if (cross) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _rateController,
              decoration: InputDecoration(
                labelText: l10n.transferRateLabel(
                  from?.currencyCode ?? '',
                  to?.currencyCode ?? '',
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _toAmountController,
              decoration: InputDecoration(
                labelText: l10n.transferToAmountLabel,
                suffixText: to?.currencyCode,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (String? v) => _positiveAmountValidator(l10n, v),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _pickDate,
            borderRadius: AppRadius.smAll,
            child: InputDecorator(
              decoration: InputDecoration(labelText: l10n.transactionDateLabel),
              child: Text(_formatDate(_valueDate)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.transactionNoteLabel),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : () => _save(wallets),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }

  /// A dropdown label for [w]: "Hesap / Cüzdan (TRY) · ₺1.234,56". The live
  /// balance (wallet's own currency) is appended once loaded; while loading it is
  /// simply omitted so the dropdown never blocks (§D.4).
  Widget _walletLabel(Wallet w, Map<int, String> accountNames) {
    final String account = accountNames[w.accountId] ?? '';
    final String head = '$account / ${w.name} (${w.currencyCode})';
    final CurrencyService currency = ref.watch(currencyServiceProvider);
    final AsyncValue<int> balance = ref.watch(walletBalanceProvider(w.id));
    final String label = balance.maybeWhen(
      data: (int minor) =>
          '$head · ${currency.format(minor, w.currencyCode)}',
      orElse: () => head,
    );
    return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  String? _positiveAmountValidator(AppLocalizations l10n, String? value) {
    final Decimal? parsed = parseTurkishAmount(value ?? '');
    if (parsed == null) {
      return l10n.validationInvalidAmount;
    }
    if (parsed <= Decimal.zero) {
      return l10n.transferErrorNonPositive;
    }
    return null;
  }

  static String _formatDate(DateTime date) {
    final String d = date.day.toString().padLeft(2, '0');
    final String m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }
}
