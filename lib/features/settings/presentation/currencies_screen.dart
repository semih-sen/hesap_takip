import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/currency/currency.dart';
import '../../../core/currency/currency_service.dart';
import '../../../data/repositories/currency_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import 'currency_form_page.dart';

class CurrenciesScreen extends ConsumerWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Currency>> currenciesState = ref.watch(currenciesProvider);
    final String primaryCurrency = ref.watch(primaryCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Para Birimleri'),
      ),
      body: currenciesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Hata: $error')),
        data: (List<Currency> currencies) {
          if (currencies.isEmpty) {
            return const Center(child: Text('Hiç para birimi yok.'));
          }
          final List<String> codes = <String>[for (final Currency c in currencies) c.code]
            ..sort();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: currencies.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DropdownButtonFormField<String>(
                    initialValue: codes.contains(primaryCurrency)
                        ? primaryCurrency
                        : codes.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Birincil döviz',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in codes)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(code),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      ref
                          .read(settingsRepositoryProvider)
                          .setPrimaryCurrency(value);
                    },
                  ),
                );
              }
              index -= 1;
              final Currency c = currencies[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    c.symbol,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(c.code),
                subtitle: Text('Ondalık: ${c.minorDigits} | Sembol ${c.symbolOnLeft ? "Solda" : "Sağda"}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppSemanticColors.dark.expense,
                  onPressed: () => _confirmDelete(context, ref, c),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => CurrencyFormPage(existingCurrency: c)),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CurrencyFormPage()),
          );
        },
        tooltip: 'Para Birimi Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Currency currency) async {
    final CurrencyRepository repo = ref.read(currencyRepositoryProvider);
    try {
      final bool inUse = await repo.isCurrencyInUse(currency.code);
      if (inUse && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${currency.code} kullanımda olduğu için silinemez.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      
      if (!context.mounted) return;
      
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Silmeyi Onayla'),
          content: Text('${currency.code} para birimini silmek istediğinize emin misiniz?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İPTAL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('SİL', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        await repo.deleteCurrency(currency.code);
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
    }
  }
}
