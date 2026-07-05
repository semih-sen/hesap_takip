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
/// colored amount), Row 2 (wallet/note + value date) and a contextual Row 3.
/// Row 3 renders, in priority order: partial-payment progress > transfer
/// counter-wallet > recurring chip > category chips. The progress/transfer/
/// recurring variants render only from real fields (populated in Phases 8–10);
/// they are never faked, so today the common case is the category chips.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({super.key, required this.row});

  final TransactionListRow row;

  /// Max category chips shown inline before collapsing the rest into a "+N".
  static const int _maxChips = 3;

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
                      // Row 3 (contextual): partial-payment progress, transfer
                      // counter-wallet, recurring chip, or category chips.
                      ..._row3(context, theme, semantic, l10n),
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

  /// The contextual third row, in priority order (§10.3): partial-payment
  /// progress > transfer > recurring > category chips. Returns an empty list
  /// (no Row 3, no spacer) when nothing applies.
  List<Widget> _row3(
    BuildContext context,
    ThemeData theme,
    AppSemanticColors semantic,
    AppLocalizations l10n,
  ) {
    final Widget? content = _row3Content(context, theme, semantic, l10n);
    if (content == null) {
      return const <Widget>[];
    }
    return <Widget>[const SizedBox(height: AppSpacing.xs + 2), content];
  }

  Widget? _row3Content(
    BuildContext context,
    ThemeData theme,
    AppSemanticColors semantic,
    AppLocalizations l10n,
  ) {
    // 1) Pending (future-dated / overdue) income or expense → borç/alacak chip
    //    with the due date, plus a "Gecikmiş" emphasis when overdue (§5.1).
    if (row.isPending &&
        (row.type == TransactionType.income ||
            row.type == TransactionType.expense)) {
      return _PendingMeta(row: row, theme: theme, semantic: semantic, l10n: l10n);
    }

    // 2) Transfer → counter-wallet (Phase 8): renders only when present.
    final String? counter = row.counterWalletName;
    if (row.type == TransactionType.transfer && counter != null) {
      return _MetaChip(
        icon: Icons.swap_horiz,
        label: l10n.transactionTransferTo(counter),
        color: semantic.transfer,
        theme: theme,
      );
    }

    // 3) Recurring-generated → "Tekrarlayan" chip (Phase 10).
    if (row.isRecurring) {
      return _MetaChip(
        icon: Icons.repeat,
        label: l10n.transactionRecurringChip,
        color: theme.colorScheme.primary,
        theme: theme,
      );
    }

    // 4) The common case → category chips.
    if (row.categories.isNotEmpty) {
      return _categoryChips(theme, semantic);
    }
    return null;
  }

  Widget _categoryChips(ThemeData theme, AppSemanticColors semantic) {
    final List<CategoryChipData> shown = row.categories.length > _maxChips
        ? row.categories.sublist(0, _maxChips)
        : row.categories;
    final int overflow = row.categories.length - shown.length;
    return Wrap(
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final CategoryChipData c in shown)
          _CategoryChip(chip: c, theme: theme, mutedColor: semantic.textMuted),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: theme.textTheme.bodySmall?.copyWith(
              color: semantic.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
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
          Text(
            chip.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row-3 for a pending (borç/alacak) item: a colored pill + due date, with a
/// "Gecikmiş" emphasis when overdue. Pure presentational — reads only row flags.
class _PendingMeta extends StatelessWidget {
  const _PendingMeta({
    required this.row,
    required this.theme,
    required this.semantic,
    required this.l10n,
  });

  final TransactionListRow row;
  final ThemeData theme;
  final AppSemanticColors semantic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = row.type == TransactionType.income;
    final Color accent = isIncome ? semantic.income : semantic.expense;
    final String label = isIncome
        ? l10n.pendingChipReceivable
        : l10n.pendingChipDebt;
    final String due = l10n.pendingDue(
      DateFormat('d MMM yyyy', 'tr_TR').format(row.valueDate),
    );
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: AppRadius.pillAll,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            due,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: semantic.textMuted),
          ),
        ),
        if (row.isOverdue) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.pendingOverdue,
            style: theme.textTheme.labelSmall?.copyWith(
              color: semantic.expense,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
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
