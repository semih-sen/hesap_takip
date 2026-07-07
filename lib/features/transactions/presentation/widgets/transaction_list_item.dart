import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/currency/currency_service.dart';
import '../../../../data/database/tables/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../shared/entity_labels.dart';
import '../../application/transactions_providers.dart';

/// Redesigned transaction card with a 3-row layout:
///
/// **Row 1**: Description (left) … [Status badge] + Amount (right)
/// **Row 2**: Date + status badges (left) … Wallet name (right)
/// **Row 3**: [🔁 recurring] + Category badges (left) … Foreign-currency
///           equivalent (right, when the txn currency ≠ base currency)
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.row,
    required this.currency,
  });

  final TransactionListRow row;
  final CurrencyService currency;

  /// Max category chips shown inline before collapsing the rest into a "+N".
  static const int _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic =
        theme.extension<AppSemanticColors>() ?? AppSemanticColors.dark;

    final Color accountAccent = Color(row.accountColorValue);
    final Color backgroundColor = switch (row.type) {
      TransactionType.income => Colors.green.withValues(alpha: 0.10),
      TransactionType.expense => Colors.red.withValues(alpha: 0.10),
      TransactionType.transfer => semantic.transfer.withValues(alpha: 0.10),
    };
    final Color amountColor = switch (row.type) {
      TransactionType.income => semantic.income,
      TransactionType.expense => semantic.expense,
      TransactionType.transfer => semantic.transfer,
    };

    final String title = row.title ?? transactionTypeLabel(l10n, row.type);
    final String sign = row.flowDirection == FlowDirection.inflow ? '+' : '−';
    final String amountText =
        '$sign${currency.format(row.amountMinor, row.currencyCode)}';
    final String dateText = DateFormat(
      'd MMM yyyy',
      'tr_TR',
    ).format(row.valueDate);

    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.mdAll,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Left vertical stripe = owning account's color.
              Container(width: 5, color: accountAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // ── Row 1: Description + [pending badge] + Amount ──
                      _buildRow1(
                        theme,
                        semantic,
                        l10n,
                        title,
                        amountText,
                        amountColor,
                      ),
                      const SizedBox(height: 2),
                      // ── Row 2: Date + status badges … Wallet name ──
                      _buildRow2(theme, semantic, l10n, dateText),
                      const SizedBox(height: AppSpacing.xs),
                      // ── Row 3: [recurring] + categories … foreign amount ──
                      _buildRow3(theme, semantic),
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

  // ────────────────────────────── Row 1 ──────────────────────────────

  Widget _buildRow1(
    ThemeData theme,
    AppSemanticColors semantic,
    AppLocalizations l10n,
    String title,
    String amountText,
    Color amountColor,
  ) {
    // Show a pending badge for receivable/payable/overdue types.
    final bool showPendingBadge =
        row.isPending &&
        (row.type == TransactionType.income ||
            row.type == TransactionType.expense);

    return Row(
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
        if (showPendingBadge) ...<Widget>[
          _PendingIcon(row: row, l10n: l10n),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          amountText,
          style: theme.textTheme.titleMedium?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────── Row 2 ──────────────────────────────

  Widget _buildRow2(
    ThemeData theme,
    AppSemanticColors semantic,
    AppLocalizations l10n,
    String dateText,
  ) {
    // Settled status badges: "Ödendi" for completed expense, "Tahsil edildi"
    // for completed income.
    final List<Widget> badges = <Widget>[];
    if (row.status == TransactionStatus.completed) {
      if (row.type == TransactionType.expense) {
        badges.add(
          _StatusBadge(
            label: l10n.settledExpense,
            color: semantic.income,
            theme: theme,
          ),
        );
      } else if (row.type == TransactionType.income) {
        badges.add(
          _StatusBadge(
            label: l10n.settledIncome,
            color: semantic.income,
            theme: theme,
          ),
        );
      }
    } else {
      if (row.type == TransactionType.expense) {
        badges.add(
          _StatusBadge(
            label: row.isDue || row.isOverdue
                ? 'Günü gelen Borç'
                : l10n.pendingChipDebt,
            color: Colors.amber,
            theme: theme,
          ),
        );
      } else if (row.type == TransactionType.income) {
        badges.add(
          _StatusBadge(
            label: row.isDue || row.isOverdue
                ? 'Günü gelecek alacak'
                : l10n.pendingChipReceivable,
            color: Colors.amber,
            theme: theme,
          ),
        );
      }
    }

    return Row(
      children: <Widget>[
        Text(
          dateText,
          style: theme.textTheme.bodySmall?.copyWith(color: semantic.textMuted),
        ),
        if (badges.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          ...badges,
        ],
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  row.walletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────── Row 3 ──────────────────────────────

  Widget _buildRow3(ThemeData theme, AppSemanticColors semantic) {
    // Left side: [loop icon] + category chips.
    final List<Widget> left = <Widget>[];

    if (row.isRecurring) {
      left.add(Icon(Icons.loop, size: 14, color: theme.colorScheme.primary));
      if (row.categories.isNotEmpty) {
        left.add(const SizedBox(width: AppSpacing.sm));
      }
    }

    // Transfer counter-wallet chip (if applicable).
    if (row.type == TransactionType.transfer && row.counterWalletName != null) {
      final String fromWallet = row.flowDirection == FlowDirection.outflow
          ? row.walletName
          : row.counterWalletName!;
      final String toWallet = row.flowDirection == FlowDirection.outflow
          ? row.counterWalletName!
          : row.walletName;
      left.add(
        Flexible(
          child: _MetaChip(
            icon: Icons.swap_horiz,
            label: '$fromWallet -> $toWallet',
            color: semantic.transfer,
            theme: theme,
          ),
        ),
      );
    } else if (row.categories.isNotEmpty) {
      // Category chips.
      final List<CategoryChipData> shown = row.categories.length > _maxChips
          ? row.categories.sublist(0, _maxChips)
          : row.categories;
      final int overflow = row.categories.length - shown.length;
      for (int i = 0; i < shown.length; i++) {
        if (i > 0 || left.isNotEmpty) {
          left.add(const SizedBox(width: AppSpacing.xs + 2));
        }
        left.add(
          Flexible(
            child: _CategoryChip(
              chip: shown[i],
              theme: theme,
              mutedColor: semantic.textMuted,
            ),
          ),
        );
      }
      if (overflow > 0) {
        left.add(const SizedBox(width: AppSpacing.xs + 2));
        left.add(
          Text(
            '+$overflow',
            style: theme.textTheme.bodySmall?.copyWith(
              color: semantic.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    }

    // Right side: foreign-currency equivalent (only when txn currency ≠ base).
    Widget? foreignAmount;
    final int? equivalentAmountMinor = row.equivalentAmountMinor;
    final String? equivalentCurrencyCode = row.equivalentCurrencyCode;
    if (equivalentAmountMinor != null && equivalentCurrencyCode != null) {
      final String fSign = row.flowDirection == FlowDirection.inflow
          ? '+'
          : '−';
      final String baseFormatted = currency.format(
        equivalentAmountMinor,
        equivalentCurrencyCode,
      );
      foreignAmount = Text(
        '$fSign$baseFormatted',
        style: theme.textTheme.bodySmall?.copyWith(
          color: semantic.textMuted,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return SizedBox(
      height: 22,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: left.isEmpty ? <Widget>[const SizedBox.shrink()] : left,
            ),
          ),
          if (foreignAmount != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            foreignAmount,
          ],
        ],
      ),
    );
  }
}

/// A single category chip: a color dot + the category name, on a faint pill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.chip,
    required this.theme,
    required this.mutedColor,
  });

  final CategoryChipData chip;
  final ThemeData theme;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final Color dot = Color(chip.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: dot.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              chip.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact Row-1 pill marking a pending borç/alacak item. An overdue item
/// prepends a warning icon and is wrapped in a `Semantics`/`Tooltip` label.
class _PendingIcon extends StatelessWidget {
  const _PendingIcon({required this.row, required this.l10n});

  final TransactionListRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (!row.isOverdue) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
        ),
      );
    }
    return Tooltip(
      message: l10n.pendingOverdue,
      child: Semantics(
        label: l10n.pendingOverdue,
        child: const Icon(Icons.error_outline, size: 14, color: Colors.amber),
      ),
    );
  }
}

/// A slim leading-icon meta chip used by the transfer/recurring Row-3 variants.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A small status badge pill for completed settlements ("Ödendi"/"Tahsil edildi").
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.theme,
  });

  final String label;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
