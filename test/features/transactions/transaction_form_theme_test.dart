import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/app/theme/app_colors.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/transactions/presentation/transaction_form_theme.dart';

/// PART A DoD: the tinted form theme is green-weighted for income and
/// red-weighted for expense, seeded (not slammed) so contrast holds, and it is
/// ALWAYS `Brightness.dark` — no light theme is ever introduced.
void main() {
  final ThemeData base = AppTheme.dark;

  test('income tint seeds primary from the income accent and stays dark', () {
    final ThemeData theme = tintedFormTheme(base, TransactionType.income);
    expect(theme.colorScheme.brightness, Brightness.dark);
    // Seeded from AppColors.income → the primary is a green in the income hue.
    final ColorScheme seeded = ColorScheme.fromSeed(
      seedColor: AppColors.income,
      brightness: Brightness.dark,
    );
    expect(theme.colorScheme.primary, seeded.primary);
    expect(theme.colorScheme.onPrimary, seeded.onPrimary);
  });

  test('expense tint seeds primary from the expense accent and stays dark', () {
    final ThemeData theme = tintedFormTheme(base, TransactionType.expense);
    expect(theme.colorScheme.brightness, Brightness.dark);
    final ColorScheme seeded = ColorScheme.fromSeed(
      seedColor: AppColors.expense,
      brightness: Brightness.dark,
    );
    expect(theme.colorScheme.primary, seeded.primary);
  });

  test('income and expense tints differ (visible green↔red skew)', () {
    final ThemeData income = tintedFormTheme(base, TransactionType.income);
    final ThemeData expense = tintedFormTheme(base, TransactionType.expense);
    expect(income.colorScheme.primary, isNot(expense.colorScheme.primary));
  });

  test(
    'neutral surfaces are inherited from the base dark theme, not recolored',
    () {
      final ThemeData theme = tintedFormTheme(base, TransactionType.income);
      // The page stays the app's dark background — only accent roles change.
      expect(theme.colorScheme.surface, base.colorScheme.surface);
      expect(theme.colorScheme.onSurface, base.colorScheme.onSurface);
      expect(theme.colorScheme.outline, base.colorScheme.outline);
    },
  );

  test('accentForType maps income→green, expense→red', () {
    expect(accentForType(TransactionType.income), AppColors.income);
    expect(accentForType(TransactionType.expense), AppColors.expense);
  });
}
