import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../core/undo/entity_actions.dart';
import '../../../../core/undo/undo_service.dart';
import '../../../../data/models/wallet.dart';
import '../../../../data/repositories/wallet_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/appearance.dart';
import '../../../shared/undo_snackbar.dart';
import '../../../transactions/services/balance_service.dart';
import '../wallet_form_page.dart';

/// A single wallet row: colored icon, name, currency, and its live balance.
/// Provides edit / archive / delete (delete goes through the undo queue).
class WalletTile extends ConsumerWidget {
  const WalletTile({super.key, required this.wallet});

  final Wallet wallet;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final action = DeleteWalletAction(
      wallet: wallet,
      label: l10n.walletDeleted(wallet.name),
    );
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(action);
    if (!context.mounted) {
      return;
    }
    if (pendingId == null) {
      // FK-restricted: the wallet has transactions — nothing was queued/hidden.
      showInfoSnackBar(context, l10n.walletDeleteBlocked);
      return;
    }
    showUndoSnackBar(
      context,
      ref,
      pendingId: pendingId,
      message: l10n.walletDeleted(wallet.name),
    );
  }

  Future<void> _toggleArchive(WidgetRef ref) async {
    // Archiving is reversible, so it is applied immediately (no undo needed).
    await ref
        .read(walletRepositoryProvider)
        .updateWallet(
          wallet.copyWith(
            isArchived: !wallet.isArchived,
            updatedAt: DateTime.now(),
          ),
        );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            WalletFormPage(accountId: wallet.accountId, wallet: wallet),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CurrencyService currency = ref.watch(currencyServiceProvider);
    final AsyncValue<int> balance = ref.watch(walletBalanceProvider(wallet.id));
    final Color color = Color(wallet.colorValue);

    return Opacity(
      opacity: wallet.isArchived ? 0.55 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.20),
          foregroundColor: color,
          child: Icon(Appearance.iconFromCodePoint(wallet.iconCodePoint)),
        ),
        title: Row(
          children: <Widget>[
            Flexible(child: Text(wallet.name, overflow: TextOverflow.ellipsis)),
            if (wallet.isArchived) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              _ArchivedChip(label: l10n.archivedBadge),
            ],
          ],
        ),
        subtitle: Text(wallet.currencyCode),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            balance.when(
              data: (int minor) => Text(
                currency.format(minor, wallet.currencyCode),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Text('—'),
            ),
            PopupMenuButton<_WalletMenu>(
              onSelected: (_WalletMenu value) {
                switch (value) {
                  case _WalletMenu.edit:
                    _edit(context);
                  case _WalletMenu.archive:
                    _toggleArchive(ref);
                  case _WalletMenu.delete:
                    _delete(context, ref);
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_WalletMenu>>[
                    PopupMenuItem<_WalletMenu>(
                      value: _WalletMenu.edit,
                      child: Text(l10n.actionEdit),
                    ),
                    PopupMenuItem<_WalletMenu>(
                      value: _WalletMenu.archive,
                      child: Text(
                        wallet.isArchived
                            ? l10n.actionUnarchive
                            : l10n.actionArchive,
                      ),
                    ),
                    PopupMenuItem<_WalletMenu>(
                      value: _WalletMenu.delete,
                      child: Text(l10n.actionDelete),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _WalletMenu { edit, archive, delete }

class _ArchivedChip extends StatelessWidget {
  const _ArchivedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
