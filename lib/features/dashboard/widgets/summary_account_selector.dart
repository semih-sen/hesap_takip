import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/models/account.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../transactions/application/summary_providers.dart';

/// Compact, horizontally-scrollable chip strip choosing which accounts the
/// Summary aggregates over (PROJECT_PLAN Phase 7, D1/D2). "Tümü" maps to the
/// empty-set sentinel (all accounts); each account chip toggles that account.
///
/// Only ACTIVE (non-archived) accounts are listed, but "Tümü" still aggregates
/// every historical row — including those of since-archived accounts/wallets —
/// because it resolves to the empty wallet set (proactive flag F8). Selecting
/// chips updates ONLY [SummaryAccountSelection]; the List scope is untouched.
class SummaryAccountSelector extends ConsumerWidget {
  const SummaryAccountSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Account> accounts = ref
        .watch(accountsStreamProvider)
        .asData
        ?.value
        .where((Account a) => !a.isArchived)
        .toList(growable: false) ??
        const <Account>[];
    final Set<int> selection = ref.watch(summaryAccountSelectionProvider);
    final SummaryAccountSelection notifier = ref.read(
      summaryAccountSelectionProvider.notifier,
    );

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: <Widget>[
          FilterChip(
            label: Text(l10n.summaryAccountsAll),
            selected: selection.isEmpty,
            onSelected: (_) => notifier.selectAll(),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final Account account in accounts) ...<Widget>[
            FilterChip(
              label: Text(account.name),
              selected: selection.contains(account.id),
              // A slightly-thicker border in the account's own color so the
              // chips read as belonging to their accounts (§D.1). The "Tümü"
              // chip above keeps the default theme border (it has no color).
              side: BorderSide(color: Color(account.colorValue), width: 1.5),
              onSelected: (_) => notifier.toggle(account.id),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
