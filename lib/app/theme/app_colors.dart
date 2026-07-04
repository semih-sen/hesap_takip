import 'package:flutter/material.dart';

/// Dark-theme palette tokens.
///
/// This is the ONLY place raw hex values live. Widgets must never hardcode
/// colors; they read Material 3 roles from `Theme.of(context).colorScheme`
/// and finance-specific accents from [AppSemanticColors] via
/// `Theme.of(context).extension<AppSemanticColors>()`.
///
/// The app is dark-theme only (see PROJECT_PLAN §10.1); no light palette is
/// defined anywhere.
abstract final class AppColors {
  /// Seed color driving the Material 3 dark [ColorScheme]. Teal fintech accent.
  static const Color seed = Color(0xFF12B5A5);

  // ----- Neutral surfaces (dark) -----
  /// App scaffold background — the darkest neutral.
  static const Color background = Color(0xFF0E1416);

  /// Default card/sheet surface.
  static const Color surface = Color(0xFF161D20);

  /// Slightly raised surface (filled fields, selected states).
  static const Color surfaceVariant = Color(0xFF1F282C);

  /// Hairline dividers/outlines on dark surfaces.
  static const Color outline = Color(0xFF33413F);

  // ----- Text -----
  /// Primary body/foreground text on dark surfaces.
  static const Color textPrimary = Color(0xFFE6EDEC);

  /// Muted/secondary text (captions, wallet names, dates).
  static const Color textMuted = Color(0xFF8CA0A0);

  // ----- Finance-semantic accents -----
  /// Income / inflow accent (positive money movement).
  static const Color income = Color(0xFF3DD68C);

  /// Expense / outflow accent (negative money movement).
  static const Color expense = Color(0xFFFF6B6B);

  /// Transfer accent (money moving between the user's own wallets).
  static const Color transfer = Color(0xFF5B8DEF);

  /// Default color for a transaction row's vertical stripe when no category
  /// color applies.
  static const Color stripeDefault = seed;
}

/// Finance-semantic colors that are not part of the Material 3 [ColorScheme].
///
/// Exposed as a [ThemeExtension] so presentation widgets resolve income /
/// expense / transfer / stripe / muted-text tokens from the active theme
/// instead of importing [AppColors] directly. This keeps the tokens swappable
/// and testable.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.stripeDefault,
    required this.textMuted,
  });

  /// The dark-theme instance used across the app.
  static const AppSemanticColors dark = AppSemanticColors(
    income: AppColors.income,
    expense: AppColors.expense,
    transfer: AppColors.transfer,
    stripeDefault: AppColors.stripeDefault,
    textMuted: AppColors.textMuted,
  );

  final Color income;
  final Color expense;
  final Color transfer;
  final Color stripeDefault;
  final Color textMuted;

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? stripeDefault,
    Color? textMuted,
  }) {
    return AppSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      stripeDefault: stripeDefault ?? this.stripeDefault,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      stripeDefault: Color.lerp(stripeDefault, other.stripeDefault, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}
