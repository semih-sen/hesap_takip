import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/amount_parsing.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/currency/money.dart';
import '../../../core/date/app_date.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/category.dart';
import '../../../data/models/recurring_rule.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/recurring_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../categories/application/categories_providers.dart';
import '../../shared/entity_labels.dart';
import '../../transactions/presentation/transaction_form_theme.dart';
import '../../wallets/application/wallets_providers.dart';
import '../services/recurring_service.dart';

/// Create/edit a recurring rule (PROJECT_PLAN §8.4 / Phase 10).
///
/// v1 restricts [type] to income/expense (recurring transfers are out of scope;
/// §B.9-1), which also fixes `flowDirection`. Currency is DERIVED from the
/// selected wallet (not independently editable), consistent with the
/// transaction/transfer forms. A frequency builder conditionally reveals
/// `byMonthDay` (monthly/yearly) or `byWeekday` (weekly).
///
/// Creating a new rule immediately generates any already-due occurrences, so a
/// rule with a past `startDate` materializes its history at once. This also
/// powers the series-edit "this and future" replacement ([RecurringRuleFormPage.
/// replacing]).
class RecurringRuleFormPage extends ConsumerStatefulWidget {
  const RecurringRuleFormPage({super.key, this.rule})
    : template = null,
      forcedStartDate = null;

  /// Series-edit "this and future": prefill from [template] but create a NEW
  /// rule starting at [startDate] (the caller has already capped the old rule).
  const RecurringRuleFormPage.replacing({
    super.key,
    required this.template,
    required DateTime startDate,
  }) : rule = null,
       forcedStartDate = startDate;

  /// The rule being edited, or null when creating.
  final RecurringRule? rule;

  /// A rule whose parameters prefill a NEW rule (series replacement).
  final RecurringRule? template;

  /// The forced start date for a [RecurringRuleFormPage.replacing] rule.
  final DateTime? forcedStartDate;

  @override
  ConsumerState<RecurringRuleFormPage> createState() =>
      _RecurringRuleFormPageState();
}

class _RecurringRuleFormPageState extends ConsumerState<RecurringRuleFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _maxOccurrencesController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  int? _walletId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int _interval = 1;
  int? _byMonthDay;
  int _byWeekday = DateTime.monday;
  DateTime _startDate = AppDate.today();
  DateTime? _endDate;
  bool _autoPost = false;
  final List<int> _categoryIds = <int>[];
  bool _saving = false;

  /// The rule being edited (null → creating, incl. the replacing case).
  RecurringRule? get _editing => widget.rule;
  bool get _isEdit => _editing != null;

  @override
  void initState() {
    super.initState();
    final RecurringRule? source = widget.rule ?? widget.template;
    if (source != null) {
      _type = source.type == TransactionType.income
          ? TransactionType.income
          : TransactionType.expense;
      _walletId = source.walletId;
      _frequency = source.frequency;
      _interval = source.interval < 1 ? 1 : source.interval;
      _byMonthDay = source.byMonthDay;
      _byWeekday = source.byWeekday ?? DateTime.monday;
      _startDate = AppDate.dateOnly(widget.forcedStartDate ?? source.startDate);
      _endDate = source.endDate == null
          ? null
          : AppDate.dateOnly(source.endDate!);
      _autoPost = source.autoPost;
      _nameController.text = source.name;
      _amountController.text = const CurrencyService()
          .fromMinor(source.amount.minorUnits, source.currencyCode)
          .toString();
      if (source.maxOccurrences != null) {
        _maxOccurrencesController.text = source.maxOccurrences.toString();
      }
      _noteController.text = source.note ?? '';
      // Prefill categories once the widget is mounted (async).
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
    }
  }

  Future<void> _loadCategories() async {
    final RecurringRule? source = widget.rule ?? widget.template;
    if (source == null) {
      return;
    }
    final List<int> ids = await ref
        .read(recurringRepositoryProvider)
        .getCategoryIds(source.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _categoryIds
        ..clear()
        ..addAll(ids);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _maxOccurrencesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  CategoryType get _categoryType => _type == TransactionType.income
      ? CategoryType.income
      : CategoryType.expense;

  Wallet? _selectedWallet(List<Wallet> wallets) {
    for (final Wallet w in wallets) {
      if (w.id == _walletId) {
        return w;
      }
    }
    return null;
  }

  void _onTypeChanged(TransactionType type) {
    if (type == _type) {
      return;
    }
    setState(() {
      _type = type;
      _categoryIds.clear(); // category selections are type-specific
    });
  }

  void _onFrequencyChanged(RecurrenceFrequency freq) {
    setState(() => _frequency = freq);
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = AppDate.dateOnly(picked));
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = AppDate.dateOnly(picked));
    }
  }

  Future<void> _save(List<Wallet> wallets) async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final Wallet? wallet = _selectedWallet(wallets);
    if (wallet == null) {
      return;
    }
    // End date must not precede the start date.
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.recurringValidationEndBeforeStart),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    setState(() => _saving = true);

    final CurrencyService currency = const CurrencyService();
    final String currencyCode = wallet.currencyCode;
    final Decimal amount =
        parseTurkishAmount(_amountController.text) ?? Decimal.zero;
    final int amountMinor = currency.toMinor(amount, currencyCode);
    final int? maxOccurrences = int.tryParse(
      _maxOccurrencesController.text.trim(),
    );
    final DateTime now = DateTime.now();
    // Only the constraint relevant to the chosen frequency is persisted.
    final int? byMonthDay =
        (_frequency == RecurrenceFrequency.monthly ||
            _frequency == RecurrenceFrequency.yearly)
        ? (_byMonthDay ?? _startDate.day)
        : null;
    final int? byWeekday = _frequency == RecurrenceFrequency.weekly
        ? _byWeekday
        : null;

    final RecurringRepository repo = ref.read(recurringRepositoryProvider);

    if (_isEdit) {
      final RecurringRule updated = _editing!.copyWith(
        name: _nameController.text.trim(),
        type: _type,
        flowDirection: _type == TransactionType.income
            ? FlowDirection.inflow
            : FlowDirection.outflow,
        walletId: wallet.id,
        amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
        frequency: _frequency,
        interval: _interval,
        byMonthDay: byMonthDay,
        byWeekday: byWeekday,
        startDate: _startDate,
        endDate: _endDate,
        maxOccurrences: maxOccurrences,
        autoPost: _autoPost,
        note: _emptyToNull(_noteController.text),
        updatedAt: now,
      );
      await repo.updateRule(updated);
      await repo.setCategories(updated.id, _categoryIds);
    } else {
      final RecurringRule created = RecurringRule(
        id: 0,
        name: _nameController.text.trim(),
        type: _type,
        flowDirection: _type == TransactionType.income
            ? FlowDirection.inflow
            : FlowDirection.outflow,
        walletId: wallet.id,
        amount: Money(minorUnits: amountMinor, currencyCode: currencyCode),
        frequency: _frequency,
        interval: _interval,
        byMonthDay: byMonthDay,
        byWeekday: byWeekday,
        startDate: _startDate,
        endDate: _endDate,
        maxOccurrences: maxOccurrences,
        generatedCount: 0,
        autoPost: _autoPost,
        isActive: true,
        note: _emptyToNull(_noteController.text),
        createdAt: now,
        updatedAt: now,
      );
      final int id = await repo.createRule(created);
      await repo.setCategories(id, _categoryIds);
      // Materialize any already-due occurrences immediately.
      await ref.read(recurringServiceProvider).generateDueEntries(now);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Wallet>> walletsAsync = ref.watch(allWalletsProvider);

    return AnimatedTheme(
      data: tintedFormTheme(Theme.of(context), _type),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.recurringEdit : l10n.recurringAdd),
        ),
        body: SafeArea(
          child: walletsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) =>
                Center(child: Text(l10n.errorGeneric)),
            data: (List<Wallet> allWallets) {
              final List<Wallet> wallets = allWallets
                  .where((Wallet w) => !w.isArchived)
                  .toList(growable: false);
              return _buildForm(context, l10n, wallets);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    List<Wallet> wallets,
  ) {
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
          // ----- Name -----
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.recurringNameLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (String? value) =>
                (value == null || value.trim().isEmpty)
                ? l10n.validationRequired
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Type (income/expense only) -----
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
          // ----- Wallet (fixes currency) -----
          DropdownButtonFormField<int>(
            initialValue: _walletId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.recurringWalletLabel,
              border: const OutlineInputBorder(),
            ),
            items: wallets
                .map(
                  (Wallet w) => DropdownMenuItem<int>(
                    value: w.id,
                    child: Text(
                      '${accountNames[w.accountId] ?? ''} / ${w.name} '
                      '(${w.currencyCode})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            validator: (int? value) =>
                value == null ? l10n.validationRequired : null,
            onChanged: (int? value) => setState(() => _walletId = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Amount -----
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.recurringAmountLabel,
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
          const SizedBox(height: AppSpacing.xl),
          // ----- Frequency builder -----
          DropdownButtonFormField<RecurrenceFrequency>(
            initialValue: _frequency,
            decoration: InputDecoration(
              labelText: l10n.recurringFrequencyLabel,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<RecurrenceFrequency>>[
              DropdownMenuItem<RecurrenceFrequency>(
                value: RecurrenceFrequency.daily,
                child: Text(l10n.recurringFrequencyDaily),
              ),
              DropdownMenuItem<RecurrenceFrequency>(
                value: RecurrenceFrequency.weekly,
                child: Text(l10n.recurringFrequencyWeekly),
              ),
              DropdownMenuItem<RecurrenceFrequency>(
                value: RecurrenceFrequency.monthly,
                child: Text(l10n.recurringFrequencyMonthly),
              ),
              DropdownMenuItem<RecurrenceFrequency>(
                value: RecurrenceFrequency.yearly,
                child: Text(l10n.recurringFrequencyYearly),
              ),
            ],
            onChanged: (RecurrenceFrequency? v) {
              if (v != null) {
                _onFrequencyChanged(v);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _IntervalStepper(
            label: l10n.recurringIntervalLabel(_interval, _unitLabel(l10n)),
            value: _interval,
            onChanged: (int v) => setState(() => _interval = v),
          ),
          if (_frequency == RecurrenceFrequency.monthly ||
              _frequency == RecurrenceFrequency.yearly) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              key: const ValueKey<String>('byMonthDay'),
              initialValue: _byMonthDay,
              decoration: InputDecoration(
                labelText: l10n.recurringByMonthDayLabel,
                border: const OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                for (int d = 1; d <= 31; d++)
                  DropdownMenuItem<int>(value: d, child: Text('$d')),
              ],
              onChanged: (int? v) => setState(() => _byMonthDay = v),
            ),
          ],
          if (_frequency == RecurrenceFrequency.weekly) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              key: const ValueKey<String>('byWeekday'),
              initialValue: _byWeekday,
              decoration: InputDecoration(
                labelText: l10n.recurringByWeekdayLabel,
                border: const OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<int>>[
                for (int d = 1; d <= 7; d++)
                  DropdownMenuItem<int>(value: d, child: Text(_weekdayName(d))),
              ],
              onChanged: (int? v) =>
                  setState(() => _byWeekday = v ?? DateTime.monday),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          // ----- Start / end dates -----
          OutlinedButton.icon(
            onPressed: _pickStartDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              '${l10n.recurringStartDateLabel}: '
              '${DateFormat('d MMMM yyyy', 'tr_TR').format(_startDate)}',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event_busy),
                  label: Text(
                    _endDate == null
                        ? l10n.recurringEndDateLabel
                        : '${l10n.recurringEndDateLabel}: '
                              '${DateFormat('d MMMM yyyy', 'tr_TR').format(_endDate!)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_endDate != null)
                IconButton(
                  tooltip: l10n.recurringEndDateClear,
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _endDate = null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Max occurrences -----
          TextFormField(
            controller: _maxOccurrencesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.recurringMaxOccurrencesLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- autoPost -----
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.recurringAutoPostLabel),
            subtitle: Text(l10n.recurringAutoPostCaption),
            value: _autoPost,
            onChanged: (bool v) => setState(() => _autoPost = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Categories -----
          Text(
            l10n.recurringCategoriesLabel,
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
                      onSelected: (bool selected) => setState(() {
                        if (selected) {
                          _categoryIds.add(c.id);
                        } else {
                          _categoryIds.remove(c.id);
                        }
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: AppSpacing.lg),
          // ----- Note -----
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: l10n.recurringNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(wallets),
            icon: const Icon(Icons.check),
            label: Text(l10n.actionSave),
          ),
        ],
      ),
    );
  }

  String _unitLabel(AppLocalizations l10n) => switch (_frequency) {
    RecurrenceFrequency.daily => l10n.recurringUnitDay,
    RecurrenceFrequency.weekly => l10n.recurringUnitWeek,
    RecurrenceFrequency.monthly => l10n.recurringUnitMonth,
    RecurrenceFrequency.yearly => l10n.recurringUnitYear,
  };

  static String _weekdayName(int weekday) {
    // 1 = Monday … 7 = Sunday, localized via intl's tr symbols.
    final DateTime ref = DateTime(2024, 1, 1); // a Monday
    return DateFormat(
      'EEEE',
      'tr_TR',
    ).format(ref.add(Duration(days: weekday - 1)));
  }
}

/// A compact "her N units" stepper for the recurrence interval (min 1).
class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < 999 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
