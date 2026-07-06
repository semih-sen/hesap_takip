import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';
import 'package:hesap_takip/app/theme/app_spacing.dart';
import 'package:hesap_takip/core/currency/currency.dart';
import 'package:hesap_takip/core/currency/currency_service.dart';
import 'package:hesap_takip/data/repositories/settings_repository.dart';
import 'package:hesap_takip/features/settings/presentation/currencies_screen.dart';
import 'package:hesap_takip/features/settings/presentation/exchange_rates_screen.dart';
import 'package:hesap_takip/features/settings/services/backup_service.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// The real Settings screen (PROJECT_PLAN §11 / Phase 11): base currency (with a
/// historical-immutability warning), first day of week, exchange-rate cache
/// management, and JSON backup export/import.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeBaseCurrency(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String current = ref.read(baseCurrencyProvider);
    final CurrencyService currencyService = ref.read(currencyServiceProvider);
    
    final List<String> codes = <String>[
      for (final Currency c in currencyService.all) c.code,
    ]..sort();

    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final String code in codes)
              ListTile(
                title: Text('$code · ${currencyService.byCode(code).symbol}'),
                trailing: code == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !context.mounted) {
      return;
    }

    // Historical-immutability warning before applying (§E.3).
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.baseCurrencyChangeWarningTitle),
            content: Text(l10n.baseCurrencyChangeWarningBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionContinue),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    await ref.read(settingsRepositoryProvider).setBaseCurrency(picked);
  }

  Future<void> _changeFirstDay(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int current =
        ref.read(settingsProvider).asData?.value.firstDayOfWeek ?? 1;
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(l10n.settingsFirstDayMonday),
              trailing: current == 1 ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(1),
            ),
            ListTile(
              title: Text(l10n.settingsFirstDaySunday),
              trailing: current == 7 ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(7),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !context.mounted) {
      return;
    }
    await ref.read(settingsRepositoryProvider).setFirstDayOfWeek(picked);
  }

  void _openExchangeRates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ExchangeRatesScreen()),
    );
  }

  void _openCurrencies(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CurrenciesScreen()),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String json = await ref.read(backupServiceProvider).exportToJson();
      final Uint8List bytes = Uint8List.fromList(utf8.encode(json));
      final String stamp = DateFormat(
        'yyyyMMdd_HHmmss',
      ).format(DateTime.now());
      final String fileName = 'hesap_takip_backup_$stamp.json';

      final String? path = await FilePicker.saveFile(
        dialogTitle: l10n.settingsBackupExport,
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (path == null) {
        return; // cancelled
      }
      // On desktop, saveFile returns a path but does not write the bytes; on
      // mobile it already has. Ensure the file exists with content either way.
      try {
        final File file = File(path);
        if (!file.existsSync() || file.lengthSync() == 0) {
          await file.writeAsBytes(bytes);
        }
      } on FileSystemException {
        // Mobile SAF path may not be a plain File — bytes were already written.
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.backupExportSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.backupError),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) {
      return;
    }
    final PlatformFile file = result.files.first;
    final Uint8List? bytes =
        file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);
    if (bytes == null || !context.mounted) {
      return;
    }

    // Destructive confirmation (§E.5).
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n.backupImportWarningTitle),
            content: Text(l10n.backupImportWarningBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionContinue),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(backupServiceProvider).importFromJson(utf8.decode(bytes));
    } on BackupFormatException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.backupImportInvalid),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.backupError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (!context.mounted) {
      return;
    }
    // Ask the user to restart (§E.5) — simpler than hot-reloading every stream.
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.backupImportSuccessTitle),
        content: Text(l10n.backupImportSuccessBody),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String base = ref.watch(baseCurrencyProvider);
    final int firstDay =
        ref.watch(settingsProvider).asData?.value.firstDayOfWeek ?? 1;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            _SectionHeader(l10n.settingsSectionGeneral),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: Text(l10n.settingsBaseCurrencyLabel),
              subtitle: Text(base),
              onTap: () => _changeBaseCurrency(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: Text(l10n.settingsFirstDayOfWeekLabel),
              subtitle: Text(
                firstDay == 7
                    ? l10n.settingsFirstDaySunday
                    : l10n.settingsFirstDayMonday,
              ),
              onTap: () => _changeFirstDay(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(l10n.settingsExchangeRatesLabel),
              subtitle: Text(l10n.settingsExchangeRatesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openExchangeRates(context),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Para Birimleri'),
              subtitle: const Text('Para birimi ekle veya düzelt'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCurrencies(context),
            ),
            const Divider(),
            _SectionHeader(l10n.settingsBackupLabel),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.settingsBackupExport),
              onTap: () => _export(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.settingsBackupImport),
              onTap: () => _import(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
