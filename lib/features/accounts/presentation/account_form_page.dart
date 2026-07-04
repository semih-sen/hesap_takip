import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/database/tables/enums.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/appearance.dart';
import '../../shared/entity_labels.dart';

/// Create/edit form for an [Account]. A null [account] means create.
///
/// Edits are saved immediately through the repository (a reversible, non-
/// destructive change); only DELETE is routed through the undo queue.
class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late AccountType _type;
  late int _colorValue;
  late int _iconCodePoint;
  bool _saving = false;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final Account? a = widget.account;
    _nameController = TextEditingController(text: a?.name ?? '');
    _type = a?.type ?? AccountType.bank;
    _colorValue = a?.colorValue ?? Appearance.colors.first;
    _iconCodePoint =
        a?.iconCodePoint ?? Appearance.accountIcons.first.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _saving = true);
    final AccountRepository repo = ref.read(accountRepositoryProvider);
    final DateTime now = DateTime.now();
    final String name = _nameController.text.trim();

    if (_isEdit) {
      await repo.updateAccount(
        widget.account!.copyWith(
          name: name,
          type: _type,
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          updatedAt: now,
        ),
      );
    } else {
      await repo.createAccount(
        Account(
          id: 0,
          name: name,
          type: _type,
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.accountEdit : l10n.accountAdd)),
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
                  labelText: l10n.accountNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                    ? l10n.validationRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.accountTypeLabel,
                  border: const OutlineInputBorder(),
                ),
                items: AccountType.values
                    .map(
                      (AccountType t) => DropdownMenuItem<AccountType>(
                        value: t,
                        child: Text(accountTypeLabel(l10n, t)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (AccountType? value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
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
                icons: Appearance.accountIcons,
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
