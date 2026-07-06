import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../data/repositories/currency_repository.dart';

class CurrencyFormPage extends ConsumerStatefulWidget {
  const CurrencyFormPage({super.key, this.existingCurrency});

  final Currency? existingCurrency;

  @override
  ConsumerState<CurrencyFormPage> createState() => _CurrencyFormPageState();
}

class _CurrencyFormPageState extends ConsumerState<CurrencyFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _codeController;
  late final TextEditingController _symbolController;
  late final TextEditingController _minorDigitsController;
  bool _symbolOnLeft = true;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.existingCurrency?.code);
    _symbolController = TextEditingController(text: widget.existingCurrency?.symbol);
    _minorDigitsController = TextEditingController(text: widget.existingCurrency?.minorDigits.toString() ?? '2');
    _symbolOnLeft = widget.existingCurrency?.symbolOnLeft ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _symbolController.dispose();
    _minorDigitsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final Currency newCurrency = Currency(
        code: _codeController.text.toUpperCase(),
        symbol: _symbolController.text,
        minorDigits: int.parse(_minorDigitsController.text),
        symbolOnLeft: _symbolOnLeft,
      );
      
      await ref.read(currencyRepositoryProvider).saveCurrency(newCurrency);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We will use Turkish strings manually since we don't have L10n entries yet.
    // Rule: UI in Turkish.
    final bool isEdit = widget.existingCurrency != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Para Birimini Düzenle' : 'Para Birimi Ekle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Kısaltma (örn. TRY, USD)',
                hintText: '3 harfli ISO kodu',
              ),
              enabled: !isEdit, // Can't edit primary key.
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) return 'Kısaltma gereklidir';
                if (value.trim().length != 3) return 'Tam 3 harf olmalıdır';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: 'Sembol (örn. ₺, \$)',
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) return 'Sembol gereklidir';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _minorDigitsController,
              decoration: const InputDecoration(
                labelText: 'Kuruş Hanesi (Ondalık)',
                hintText: 'Genellikle 2 (örn. Kuruş, Cent)',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) return 'Kuruş hanesi gereklidir';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              title: const Text('Sembol Sola Yazılsın'),
              subtitle: const Text('Açık: \$100, Kapalı: 100 ₺'),
              value: _symbolOnLeft,
              onChanged: (bool value) {
                setState(() => _symbolOnLeft = value);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
