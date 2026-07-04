import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds the application's single, dark Material 3 theme.
///
/// PROJECT_PLAN §10.1: dark theme ONLY. No light [ThemeData] and no
/// `ThemeMode.system` exist anywhere — [MaterialApp.router] is configured with
/// `themeMode: ThemeMode.dark` and only this theme is provided.
abstract final class AppTheme {
  /// The one theme used by the app.
  static ThemeData get dark {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.seed,
        ).copyWith(
          // Pin the neutral surfaces to our palette for a cohesive dark look,
          // while keeping the seed-derived primary/secondary tonal roles.
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerLowest: AppColors.background,
          surfaceContainerHighest: AppColors.surfaceVariant,
          outline: AppColors.outline,
        );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.dark],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.20),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : AppColors.textMuted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
