import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../core/undo/entity_actions.dart';
import '../../../../core/undo/undo_service.dart';
import '../../../../data/models/account.dart';
import '../../../../data/models/wallet.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/appearance.dart';
import '../../../shared/entity_labels.dart';
import '../../../shared/undo_snackbar.dart';
import '../../../transactions/services/balance_service.dart';
import '../../../wallets/application/wallets_providers.dart';
import '../../../wallets/presentation/wallet_form_page.dart';
import '../../../wallets/presentation/widgets/wallet_tile.dart';
import '../account_form_page.dart';

/// One account rendered as a card: header (icon, name, type, actions) followed
/// by its wallets (each with a live balance) and an "add wallet" affordance.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.account});

  final Account account;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final action = DeleteAccountAction(
      account: account,
      label: l10n.accountDeleted(account.name),
    );
    final String? pendingId = await ref
        .read(undoServiceProvider)
        .enqueue(action);
    if (!context.mounted) {
      return;
    }
    if (pendingId == null) {
      // FK-restricted: the account still has wallets.
      showInfoSnackBar(context, l10n.accountDeleteBlocked);
      return;
    }
    showUndoSnackBar(
      context,
      ref,
      pendingId: pendingId,
      message: l10n.accountDeleted(account.name),
    );
  }

  Future<void> _toggleArchive(WidgetRef ref) async {
    await ref
        .read(accountRepositoryProvider)
        .updateAccount(
          account.copyWith(
            isArchived: !account.isArchived,
            updatedAt: DateTime.now(),
          ),
        );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountFormPage(account: account),
      ),
    );
  }

  void _addWallet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletFormPage(accountId: account.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color color = Color(account.colorValue);
    final List<Wallet> wallets = ref.watch(visibleWalletsProvider(account.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Opacity(
              opacity: account.isArchived ? 0.55 : 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.20),
                  foregroundColor: color,
                  child: Icon(
                    Appearance.iconFromCodePoint(account.iconCodePoint),
                  ),
                ),
                title: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (account.isArchived) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.archivedBadge,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(accountTypeLabel(l10n, account.type)),
                    _AccountTotal(accountId: account.id),
                  ],
                ),
                trailing: PopupMenuButton<_AccountMenu>(
                  onSelected: (_AccountMenu value) {
                    switch (value) {
                      case _AccountMenu.edit:
                        _edit(context);
                      case _AccountMenu.addWallet:
                        _addWallet(context);
                      case _AccountMenu.archive:
                        _toggleArchive(ref);
                      case _AccountMenu.delete:
                        _delete(context, ref);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_AccountMenu>>[
                        PopupMenuItem<_AccountMenu>(
                          value: _AccountMenu.edit,
                          child: Text(l10n.actionEdit),
                        ),
                        PopupMenuItem<_AccountMenu>(
                          value: _AccountMenu.addWallet,
                          child: Text(l10n.walletAdd),
                        ),
                        PopupMenuItem<_AccountMenu>(
                          value: _AccountMenu.archive,
                          child: Text(
                            account.isArchived
                                ? l10n.actionUnarchive
                                : l10n.actionArchive,
                          ),
                        ),
                        PopupMenuItem<_AccountMenu>(
                          value: _AccountMenu.delete,
                          child: Text(l10n.actionDelete),
                        ),
                      ],
                ),
              ),
            ),
            const Divider(height: 1),
            if (wallets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  l10n.walletsEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final Wallet wallet in wallets)
                WalletTile(key: ValueKey<int>(wallet.id), wallet: wallet),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addWallet(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.actionAddWallet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountMenu { edit, addWallet, archive, delete }

/// The account's aggregate balance across its non-archived wallets, converted to
/// the base currency (§D.5). Labeled so it reads as a converted total, not a
/// same-currency sum. Mirrors `WalletTile`'s loading/error fallbacks.
class _AccountTotal extends ConsumerWidget {
  const _AccountTotal({required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String base = ref.watch(baseCurrencyProvider);
    final AsyncValue<int> total = ref.watch(
      accountTotalBalanceProvider(accountId),
    );
    final ThemeData theme = Theme.of(context);
    return total.when(
      data: (int minor) {
        final CurrencyService currency = ref.watch(currencyServiceProvider);
        return Text(
          l10n.accountTotalLabel(currency.format(minor, base)),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        );
      },
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const Text('—'),
    );
  }
}
