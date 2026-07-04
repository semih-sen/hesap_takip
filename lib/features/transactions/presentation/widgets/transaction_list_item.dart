import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../data/database/tables/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/entity_labels.dart';
import '../../application/transactions_providers.dart';

/// The bespoke transaction row (PROJECT_PLAN §10.3). A **pure presentational**
/// widget taking a single [TransactionListRow] — it reads no providers, so a
/// large list rebuilds cheaply. Wrap instances with `ValueKey(row.id)`.
///
/// Layout contract: a fixed-radius container with a left vertical accent stripe
/// and a transparent accent-tinted background; a `Column` of Row 1 (title +
/// colored amount) and Row 2 (wallet/note + value date). Row 3 (partial-payment
/// progress / transfer counter-wallet / recurring / category chips) is a
/// deliberate seam Phase 6 fills — it is intentionally not faked here.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({super.key, required this.row});

  final TransactionListRow row;

  /// Stateless formatting engine (no rate math on this path); constructing it
  /// directly keeps the widget provider-free and const-friendly.
  static const CurrencyService _currency = CurrencyService();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;

    final Color accent = Color(row.accentColorValue);
    final Color amountColor = switch (row.type) {
      TransactionType.income => semantic.income,
      TransactionType.expense => semantic.expense,
      TransactionType.transfer => semantic.transfer,
    };

    final String title = row.title ?? transactionTypeLabel(l10n, row.type);
    final String sign = row.flowDirection == FlowDirection.inflow ? '+' : '−';
    final String amountText =
        '$sign${_currency.format(row.amountMinor, row.currencyCode)}';
    final String dateText = DateFormat(
      'd MMM yyyy',
      'tr_TR',
    ).format(row.valueDate);
    final String? secondary = _secondaryLine(title);

    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: AppRadius.mdAll,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Left vertical accent stripe (full height; corners clipped round).
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Row 1: title + amount.
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            amountText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: amountColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Row 2: wallet (+ note/payee) and value date.
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              secondary == null
                                  ? row.walletName
                                  : '${row.walletName} · $secondary',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: semantic.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            dateText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                        ],
                      ),
                      // Row 3 seam (Phase 6): partial-payment progress, transfer
                      // counter-wallet, recurring chip, or category chips.
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The optional secondary text on Row 2: the note, else a payee that isn't
  /// already the title (so it is not shown twice).
  String? _secondaryLine(String title) {
    final String? note = _clean(row.note);
    if (note != null) {
      return note;
    }
    final String? payee = _clean(row.payee);
    if (payee != null && payee != title) {
      return payee;
    }
    return null;
  }

  static String? _clean(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
