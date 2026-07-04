import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/currency/money.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/appearance.dart';

/// Create/edit form for a [Wallet] under [accountId]. A null [wallet] means
/// create.
///
/// Decision: a wallet's currency is FIXED after creation. Changing it would
/// silently invalidate every stored transaction currency/rate snapshot and the
/// computed balance, so on edit the currency field is disabled.
class WalletFormPage extends ConsumerStatefulWidget {
  const WalletFormPage({super.key, required this.accountId, this.wallet});

  final int accountId;
  final Wallet? wallet;

  @override
  ConsumerState<WalletFormPage> createState() => _WalletFormPageState();
}

class _WalletFormPageState extends ConsumerState<WalletFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _currencyCode;
  late int _colorValue;
  late int _iconCodePoint;
  bool _saving = false;

  bool get _isEdit => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final Wallet? w = widget.wallet;
    _nameController = TextEditingController(text: w?.name ?? '');
    _currencyCode = w?.currencyCode ?? 'TRY';
    _colorValue = w?.colorValue ?? Appearance.colors.first;
    _iconCodePoint = w?.iconCodePoint ?? Appearance.walletIcons.first.codePoint;
    _balanceController = TextEditingController(
      text: w == null ? '' : _initialText(w),
    );
  }

  String _initialText(Wallet w) {
    // Show the initial balance in major units using the service (display only).
    final CurrencyService service = ref.read(currencyServiceProvider);
    if (w.initialBalance.minorUnits == 0) {
      return '';
    }
    return service
        .fromMinor(w.initialBalance.minorUnits, w.currencyCode)
        .toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Parses the initial-balance field using Turkish convention: `.` groups
  /// thousands and `,` is the decimal separator (e.g. `1.234,56`). Empty is 0.
  /// Returns null when the input is not a valid number.
  Decimal? _parseAmount(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return Decimal.zero;
    }
    final String normalized = trimmed
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return Decimal.tryParse(normalized);
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _saving = true);
    final CurrencyService service = ref.read(currencyServiceProvider);
    final WalletRepository repo = ref.read(walletRepositoryProvider);
    final Decimal amount =
        _parseAmount(_balanceController.text) ?? Decimal.zero;
    final int minorUnits = service.toMinor(amount, _currencyCode);
    final DateTime now = DateTime.now();
    final String name = _nameController.text.trim();
    final Money balance = Money(
      minorUnits: minorUnits,
      currencyCode: _currencyCode,
    );

    if (_isEdit) {
      await repo.updateWallet(
        widget.wallet!.copyWith(
          name: name,
          initialBalance: balance,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          updatedAt: now,
        ),
      );
    } else {
      await repo.createWallet(
        Wallet(
          id: 0,
          accountId: widget.accountId,
          name: name,
          initialBalance: balance,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          isArchived: false,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
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
    final List<Currency> currencies = CurrencyRegistry.all;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.walletEdit : l10n.walletAdd)),
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
                  labelText: l10n.walletNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                    ? l10n.validationRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: InputDecoration(
                  labelText: l10n.walletCurrencyLabel,
                  border: const OutlineInputBorder(),
                  helperText: _isEdit ? l10n.walletCurrencyFixedHint : null,
                  helperMaxLines: 2,
                ),
                items: currencies
                    .map(
                      (Currency c) => DropdownMenuItem<String>(
                        value: c.code,
                        child: Text('${c.code}  ${c.symbol}'),
                      ),
                    )
                    .toList(growable: false),
                // Currency is immutable after creation (see class doc).
                onChanged: _isEdit
                    ? null
                    : (String? value) {
                        if (value != null) {
                          setState(() => _currencyCode = value);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.walletInitialBalanceLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? value) => _parseAmount(value ?? '') == null
                    ? l10n.validationInvalidAmount
                    : null,
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
                icons: Appearance.walletIcons,
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
