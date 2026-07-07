import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/account.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../transactions/presentation/transfer_form_page.dart';
import '../application/accounts_providers.dart';
import 'account_form_page.dart';
import 'widgets/account_card.dart';

/// Accounts & wallets home (Phase 3). Lists accounts, each with its wallets and
/// live balances. Loading/empty/error states are all handled.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _addAccount(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AccountFormPage()));
  }

  void _addTransfer(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TransferFormPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Account>> stream = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.transferAdd,
            onPressed: () => _addTransfer(context),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAccount(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.accountAdd),
      ),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _ErrorState(
          message: l10n.errorGeneric,
          onRetry: () => ref.invalidate(accountsStreamProvider),
          retryLabel: l10n.actionRetry,
        ),
        data: (_) {
          // The visible list applies the pending-undo overlay over the stream.
          final List<Account> accounts = ref.watch(visibleAccountsProvider);
          if (accounts.isEmpty) {
            return _EmptyState(
              title: l10n.accountsEmptyTitle,
              message: l10n.accountsEmptyMessage,
            );
          }
          return ListView.separated(
            padding: AppSpacing.screenPadding,
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final Account account = accounts[index];
              return AccountCard(
                key: ValueKey<int>(account.id),
                account: account,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 56, color: AppColors.expense),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
