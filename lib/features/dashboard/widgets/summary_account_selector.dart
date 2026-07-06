import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../data/models/account.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../transactions/application/summary_providers.dart';

/// Compact, horizontally-scrollable chip strip choosing which account the
/// Summary aggregates over. The "Tümü" option has been removed; the dashboard
/// initializes with the user's default account (or the first active account).
///
/// Only ACTIVE (non-archived) accounts are listed. Selecting chips updates ONLY
/// [SummaryAccountSelection]; the List scope is untouched.
class SummaryAccountSelector extends ConsumerStatefulWidget {
  const SummaryAccountSelector({super.key});

  @override
  ConsumerState<SummaryAccountSelector> createState() =>
      _SummaryAccountSelectorState();
}

class _SummaryAccountSelectorState
    extends ConsumerState<SummaryAccountSelector> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
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

    // On first build with data, initialize the selection to the default account
    // so the dashboard always opens with a meaningful scope.
    if (!_initialized && accounts.isNotEmpty && selection.isEmpty) {
      _initialized = true;
      final Account? defaultAcct = ref.read(defaultAccountProvider);
      if (defaultAcct != null) {
        // Schedule after the current build to avoid mutating state during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifier.setSelection(<int>{defaultAcct.id});
        });
      }
    }

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: <Widget>[
          for (final Account account in accounts) ...<Widget>[
            FilterChip(
              label: Text(account.name),
              selected: selection.contains(account.id),
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
