import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/amount_parsing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/currency/money.dart';
import '../../../core/currency/split_allocation.dart';
import '../../../core/date/app_date.dart';
import '../../../core/undo/entity_actions.dart';
import '../../../core/undo/undo_service.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/exchange_rate_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../categories/application/categories_providers.dart';
import '../../shared/entity_labels.dart';
import '../../shared/undo_snackbar.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/balance_service.dart';
import 'transaction_form_theme.dart';

/// Create/edit an income or expense transaction (PROJECT_PLAN §5.2–§5.3).
///
/// Records the currency + rate snapshot (§6): the amount is entered in the
/// selected wallet's currency; when that differs from the base currency a manual
/// rate field (prefilled from the cache) is shown and `baseAmountMinor` is
/// snapshotted at write time. Categories are multi-selected with an optional,
/// minimal per-category split. Writes go through
/// `createTransactionWithCategories` / `updateTransactionWithCategories` in one
/// atomic DB transaction. Only DELETE is routed through the undo queue.
class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, this.transactionId});

  final int? transactionId;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _payeeController = TextEditingController();
  final Map<int, TextEditingController> _splitControllers =
      <int, TextEditingController>{};

  TransactionType _type = TransactionType.expense;
  int? _walletId;
  DateTime _valueDate = AppDate.today();
  final List<int> _categoryIds = <int>[]; // ordered → last absorbs remainder
  bool _splitEnabled = false;
  bool _saving = false;

  /// True until an edited transaction has been loaded (prefill).
  bool _loading = false;
  Transaction? _editing;

  bool get _isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onPreviewInputChanged);
    _rateController.addListener(_onPreviewInputChanged);
    if (_isEdit) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    _payeeController.dispose();
    for (final TextEditingController c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPreviewInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  CurrencyService get _currency => ref.read(currencyServiceProvider);

  Future<void> _loadForEdit() async {
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final Transaction? txn = await repo.findTransaction(widget.transactionId!);
    if (txn == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final List<TransactionCategoryLink> links = await repo.categoryLinksFor(
      txn.id,
    );
    final String base = ref.read(baseCurrencyProvider);
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = txn;
      _type = txn.type;
      _walletId = txn.walletId;
      _valueDate = AppDate.dateOnly(txn.valueDate);
      _amountController.text = _currency
          .fromMinor(txn.amount.minorUnits, txn.currencyCode)
          .toString();
      if (txn.currencyCode != base) {
        _rateController.text = txn.exchangeRateToBase.toString();
      }
      _noteController.text = txn.note ?? '';
      _payeeController.text = txn.payee ?? '';
      _categoryIds
        ..clear()
        ..addAll(links.map((TransactionCategoryLink l) => l.categoryId));
      _splitEnabled = links.any(
        (TransactionCategoryLink l) => l.allocatedAmountMinor != null,
      );
      for (final TransactionCategoryLink l in links) {
        final int? allocated = l.allocatedAmountMinor;
        _splitControllers[l.categoryId] = TextEditingController(
          text: allocated == null
              ? ''
              : _currency.fromMinor(allocated, txn.currencyCode).toString(),
        );
      }
      _loading = false;
    });
  }

  Wallet? _selectedWallet(List<Wallet> wallets) {
    for (final Wallet w in wallets) {
      if (w.id == _walletId) {
        return w;
      }
    }
    return null;
  }

  CategoryType get _categoryType => _type == TransactionType.income
      ? CategoryType.income
      : CategoryType.expense;

  void _onTypeChanged(TransactionType type) {
    if (type == _type) {
      return;
    }
    setState(() {
      _type = type;
      // Category selections are type-specific; clear incompatible ones.
      _categoryIds.clear();
      for (final TextEditingController c in _splitControllers.values) {
        c.dispose();
      }
      _splitControllers.clear();
      _splitEnabled = false;
    });
  }

  void _toggleCategory(int categoryId, bool selected) {
    setState(() {
      if (selected) {
        _categoryIds.add(categoryId);
        _splitControllers[categoryId] = TextEditingController();
      } else {
        _categoryIds.remove(categoryId);
        _splitControllers.remove(categoryId)?.dispose();
      }
    });
  }

  Future<void> _prefillRate(Wallet wallet, String base) async {
    if (wallet.currencyCode == base) {
      _rateController.text = '';
      return;
    }
    final ExchangeRateEntryLookup lookup = ExchangeRateEntryLookup(
      ref.read(exchangeRateRepositoryProvider),
    );
    final double? cached = await lookup.rate(
      wallet.currencyCode,
      base,
      _valueDate,
    );
    if (!mounted) {
      return;
    }
    _rateController.text = (cached ?? 1.0).toString();
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    final String currencyCode = wallet.currencyCode;
    final Decimal amount =
        parseTurkishAmount(_amountController.text) ?? Decimal.zero;
    final int amountMinor = _currency.toMinor(amount, currencyCode);
    final Decimal rate = currencyCode == base
        ? Decimal.one
        : (parseTurkishAmount(_rateController.text) ?? Decimal.one);
    final int baseAmountMinor = _currency.convertMinor(
      amountMinor: amountMinor,
      fromCode: currencyCode,
      toCode: base,
      rate: rate.toDouble(),
    );
    final DateTime now = DateTime.now();

    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    // Status is derived only for new rows or rows that are already completed.
    // An existing pending borc/alacak stays pending even after its due date;
    // only the explicit settle flow completes it.
    final bool keepPending =
        _isEdit &&
        (_editing!.status == TransactionStatus.pending ||
            await repo.hasSettlementChildren(_editing!.id));
    if (!mounted) {
      return;
    }
    final TransactionStatus status = keepPending
        ? TransactionStatus.pending
        : statusForValueDate(_valueDate);

    final Transaction transaction = Transaction(
      id: _editing?.id ?? 0,
      walletId: wallet.id,
      type: _type,
      flowDirection: _type == TransactionType.income
          ? FlowDirection.inflow
          : FlowDirection.outflow,
      status: status,
      amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
      exchangeRateToBase: rate,
      baseAmountMinor: baseAmountMinor,
      valueDate: _valueDate,
      note: _emptyToNull(_noteController.text),
      payee: _emptyToNull(_payeeController.text),
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final List<TransactionCategoryLink> links = _buildLinks(currencyCode);

    try {
      if (_isEdit) {
        await repo.updateTransactionWithCategories(
          transaction: transaction,
          links: links,
        );
      } else {
        await repo.createTransactionWithCategories(
          transaction: transaction,
          links: links,
        );
      }
    } on SplitAllocationException {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.validationSplitMismatch),
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

  Future<void> _confirmDelete() async {
    final Transaction? txn = _editing;
    if (txn == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.actionDelete),
            content: const Text(
              'Bu işlemi silmek istediğinizden emin misiniz?',
            ),
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
    if (!confirmed || !mounted) {
      return;
    }
    final String label = l10n.transactionDeleted;
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(DeleteTransactionAction(transaction: txn, label: label));
    if (pendingId == null || !mounted) {
      return;
    }
    showUndoSnackBar(context, ref, pendingId: pendingId, message: label);
    Navigator.of(context).pop();
  }

  /// Builds the category links. When split is enabled each selected category
  /// carries a parsed allocation (the repository reconciles them to the total,
  /// last absorbs the remainder); otherwise links are whole-transaction (null).
  List<TransactionCategoryLink> _buildLinks(String currencyCode) {
    if (_categoryIds.isEmpty) {
      return const <TransactionCategoryLink>[];
    }
    if (!_splitEnabled) {
      return <TransactionCategoryLink>[
        for (final int id in _categoryIds)
          TransactionCategoryLink(categoryId: id),
      ];
    }
    return <TransactionCategoryLink>[
      for (final int id in _categoryIds)
        TransactionCategoryLink(
          categoryId: id,
          allocatedAmountMinor: _currency.toMinor(
            parseTurkishAmount(_splitControllers[id]?.text ?? '') ??
                Decimal.zero,
            currencyCode,
          ),
        ),
    ];
  }

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String base = ref.watch(baseCurrencyProvider);
    final AsyncValue<List<Wallet>> walletsAsync = ref.watch(allWalletsProvider);
    final Color accent = accentForType(_type);

    // Wrap the whole Scaffold (AppBar included) in the type-tinted dark theme so
    // flipping Gelir↔Gider cross-fades the accent (PART A). The theme stays
    // Brightness.dark; only the accent roles change. The `showDatePicker`
    // launched from this subtree deliberately inherits the tint (on-brand).
    return AnimatedTheme(
      data: tintedFormTheme(Theme.of(context), _type),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.transactionEdit : l10n.transactionAdd),
        ),
        // A very faint top-down accent wash behind the body adds subtle depth
        // without ever reading as a colored (non-dark) page (alpha ≤ 0.06).
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                accent.withValues(alpha: 0.05),
                accent.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            child: walletsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) =>
                  Center(child: Text(l10n.errorGeneric)),
              data: (List<Wallet> wallets) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildForm(context, l10n, base, wallets);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    String base,
    List<Wallet> wallets,
  ) {
    final Wallet? wallet = _selectedWallet(wallets);
    final String? currencyCode = wallet?.currencyCode;
    final bool needsRate = currencyCode != null && currencyCode != base;
    final Map<int, String> accountNames = <int, String>{
      for (final account
          in ref.watch(accountsStreamProvider).asData?.value ??
              const <dynamic>[])
        account.id as int: account.name as String,
    };
    final List<Category> pickerCategories = ref.watch(
      categoriesForPickerProvider(_categoryType),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: <Widget>[
          // ----- Type -----
          SegmentedButton<TransactionType>(
            segments: <ButtonSegment<TransactionType>>[
              ButtonSegment<TransactionType>(
                value: TransactionType.income,
                label: Text(transactionTypeLabel(l10n, TransactionType.income)),
                icon: const Icon(Icons.south_west),
              ),
              ButtonSegment<TransactionType>(
                value: TransactionType.expense,
                label: Text(
                  transactionTypeLabel(l10n, TransactionType.expense),
                ),
                icon: const Icon(Icons.north_east),
              ),
            ],
            selected: <TransactionType>{_type},
            onSelectionChanged: (Set<TransactionType> s) =>
                _onTypeChanged(s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Wallet -----
          DropdownButtonFormField<int>(
            initialValue: _walletId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.transactionWalletLabel,
              border: const OutlineInputBorder(),
            ),
            items: wallets
                .map(
                  (Wallet w) => DropdownMenuItem<int>(
                    value: w.id,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final AsyncValue<int> balanceAsync = ref.watch(
                          walletBalanceProvider(w.id),
                        );
                        final String balanceText = balanceAsync.when(
                          data: (int balance) {
                            final String formatted = _currency.format(
                              balance,
                              w.currencyCode,
                            );
                            return ' (Bakiye: $formatted)'; // Hardcoded Turkish fallback for balance
                          },
                          loading: () => ' (...)',
                          error: (_, _) => ' (!)',
                        );
                        return Text(
                          '${accountNames[w.accountId] ?? ''} / ${w.name}$balanceText',
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                )
                .toList(growable: false),
            validator: (int? value) =>
                value == null ? l10n.validationRequired : null,
            onChanged: (int? value) {
              setState(() => _walletId = value);
              final Wallet? w = _selectedWallet(wallets);
              if (w != null) {
                _prefillRate(w, base);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Amount -----
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: currencyCode == null
                  ? l10n.transactionAmountLabel
                  : '${l10n.transactionAmountLabel} ($currencyCode)',
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
          if (needsRate) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.transactionRateLabel(currencyCode, base),
                helperText: _basePreview(currencyCode, base),
                border: const OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (!needsRate) {
                  return null;
                }
                final Decimal? parsed = parseTurkishAmount(value ?? '');
                if (parsed == null || parsed <= Decimal.zero) {
                  return l10n.validationInvalidRate;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // ----- Value date -----
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              '${l10n.transactionDateLabel}: '
              '${DateFormat('d MMMM yyyy', 'tr_TR').format(_valueDate)}',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ----- Categories -----
          Text(
            l10n.transactionCategoriesLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (pickerCategories.isEmpty)
            Text(
              l10n.transactionNoCategories,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: pickerCategories
                  .map(
                    (Category c) => FilterChip(
                      label: Text(c.name),
                      selected: _categoryIds.contains(c.id),
                      onSelected: (bool selected) =>
                          _toggleCategory(c.id, selected),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (_categoryIds.length >= 2) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.transactionSplitLabel),
              value: _splitEnabled,
              onChanged: (bool value) => setState(() => _splitEnabled = value),
            ),
            if (_splitEnabled)
              ..._categoryIds.map(
                (int id) => _splitField(id, pickerCategories, currencyCode),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // ----- Note / payee -----
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: l10n.transactionNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _payeeController,
            decoration: InputDecoration(
              labelText: l10n.transactionPayeeLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(base, wallets),
            icon: const Icon(Icons.check),
            label: Text(l10n.actionSave),
          ),
          if (_isEdit) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.actionDelete),
            ),
          ],
        ],
      ),
    );
  }

  Widget _splitField(
    int categoryId,
    List<Category> categories,
    String? currencyCode,
  ) {
    final String name = categories
        .firstWhere(
          (Category c) => c.id == categoryId,
          orElse: () => categories.first,
        )
        .name;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: _splitControllers[categoryId],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: currencyCode == null ? name : '$name ($currencyCode)',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  /// The live "≈ {baseAmount}" preview shown under the rate field.
  String? _basePreview(String currencyCode, String base) {
    final Decimal? amount = parseTurkishAmount(_amountController.text);
    final Decimal? rate = parseTurkishAmount(_rateController.text);
    if (amount == null ||
        amount <= Decimal.zero ||
        rate == null ||
        rate <= Decimal.zero) {
      return null;
    }
    final int amountMinor = _currency.toMinor(amount, currencyCode);
    final int baseMinor = _currency.convertMinor(
      amountMinor: amountMinor,
      fromCode: currencyCode,
      toCode: base,
      rate: rate.toDouble(),
    );
    return '≈ ${_currency.format(baseMinor, base)}';
  }
}

/// Thin adapter turning an [ExchangeRateRepository] lookup into a plain
/// double rate (or null), keeping the form's prefill logic terse.
class ExchangeRateEntryLookup {
  const ExchangeRateEntryLookup(this._repo);

  final ExchangeRateRepository _repo;

  Future<double?> rate(String from, String to, DateTime onOrBefore) async {
    final entry = await _repo.latestRate(from, to, onOrBefore: onOrBefore);
    return entry?.rate;
  }
}
