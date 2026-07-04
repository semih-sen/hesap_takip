import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Candidate colors and icons for accounts/wallets, plus small picker widgets.
///
/// Colors are stored as ARGB ints and icons as code points (`IconData.codePoint`)
/// on the domain models. `iconFromCodePoint` rebuilds an [IconData] for display.
abstract final class Appearance {
  /// Selectable ARGB color swatches.
  static const List<int> colors = <int>[
    0xFF12B5A5, // teal (seed)
    0xFF3DD68C, // green
    0xFF5B8DEF, // blue
    0xFF9C6ADE, // purple
    0xFFEC407A, // pink
    0xFFFF6B6B, // red
    0xFFEF9A3D, // orange
    0xFFF2C94C, // yellow
    0xFF26A69A, // cyan-teal
    0xFF8D6E63, // brown
    0xFF7E8CA0, // slate
    0xFFB0BEC5, // grey
  ];

  /// Selectable icons for accounts (const [IconData]s → a const list is fine).
  static const List<IconData> accountIcons = <IconData>[
    Icons.account_balance,
    Icons.account_balance_wallet,
    Icons.savings,
    Icons.credit_card,
    Icons.payments,
    Icons.attach_money,
    Icons.person,
    Icons.trending_up,
    Icons.home,
    Icons.business_center,
  ];

  /// Selectable icons for wallets.
  static const List<IconData> walletIcons = <IconData>[
    Icons.account_balance_wallet,
    Icons.wallet,
    Icons.credit_card,
    Icons.savings,
    Icons.payments,
    Icons.money,
    Icons.currency_exchange,
    Icons.euro,
    Icons.currency_lira,
    Icons.card_giftcard,
  ];

  /// Rebuilds a Material [IconData] from a stored [codePoint].
  ///
  /// Uses the runtime code point (not a const literal), so a release build must
  /// pass `--no-tree-shake-icons`. Debug/run and tests are unaffected.
  static IconData iconFromCodePoint(int codePoint) =>
      // ignore: non_const_argument_for_const_parameter
      IconData(codePoint, fontFamily: 'MaterialIcons');
}

/// A horizontal, single-select swatch strip bound to an ARGB [selected] value.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: Appearance.colors
          .map((int argb) {
            final bool isSelected = argb == selected;
            return _SwatchDot(
              color: Color(argb),
              selected: isSelected,
              onTap: () => onSelected(argb),
            );
          })
          .toList(growable: false),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: Colors.black87)
            : null,
      ),
    );
  }
}

/// A wrap of selectable icons bound to a code-point [selected] value.
class IconPickerRow extends StatelessWidget {
  const IconPickerRow({
    super.key,
    required this.icons,
    required this.selected,
    required this.onSelected,
  });

  final List<IconData> icons;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: icons
          .map((IconData icon) {
            final bool isSelected = icon.codePoint == selected;
            return InkResponse(
              onTap: () => onSelected(icon.codePoint),
              radius: 26,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.20)
                      : scheme.surfaceContainerHighest,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? scheme.primary : scheme.onSurface,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
