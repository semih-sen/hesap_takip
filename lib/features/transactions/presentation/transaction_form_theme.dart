import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/database/tables/enums.dart';

/// Builds a **type-tinted** variant of the app's dark theme for the transaction
/// form (PART A). Selecting *Gelir* (income) skews the form chrome
/// green-weighted; *Gider* (expense) skews it red-weighted. Every neutral
/// surface (background, surface, outline) stays the app's dark palette — the
/// page never becomes a light or solidly colored page, only *accented*.
///
/// The accent-bearing roles are derived with [ColorScheme.fromSeed] at
/// `Brightness.dark` (NEVER light — the app is dark-only, PROJECT_PLAN §10.1)
/// rather than by slamming `primary = accent`. Seeding is what keeps the
/// `on*`/container tones at proper contrast, so a `FilledButton` label and the
/// selected `SegmentedButton` segment stay legible in both tints.
///
/// Only the accent roles are copied over `base.colorScheme`; `surface`,
/// `onSurface`, `outline` and the neutral containers are left untouched, so
/// wrapping the form's `Scaffold` subtree in this theme accents the M3 chrome
/// (SegmentedButton, FilledButton, input focus/label, the date button, FAB)
/// while the page reads as the same dark background.
ThemeData tintedFormTheme(ThemeData base, TransactionType type) {
  final ColorScheme seeded = _seededSchemeFor(type);
  final ColorScheme tinted = base.colorScheme.copyWith(
    primary: seeded.primary,
    onPrimary: seeded.onPrimary,
    primaryContainer: seeded.primaryContainer,
    onPrimaryContainer: seeded.onPrimaryContainer,
    secondary: seeded.secondary,
    onSecondary: seeded.onSecondary,
    secondaryContainer: seeded.secondaryContainer,
    onSecondaryContainer: seeded.onSecondaryContainer,
    tertiary: seeded.tertiary,
    onTertiary: seeded.onTertiary,
    surfaceTint: seeded.surfaceTint,
  );
  return base.copyWith(colorScheme: tinted);
}

/// The accent driving the tint: income → green, expense → red. Phase 5 offers
/// only income/expense on this form (transfers are Phase 8), so there is no
/// transfer branch here.
Color accentForType(TransactionType type) =>
    type == TransactionType.income ? AppColors.income : AppColors.expense;

/// Seeding a full [ColorScheme] is the only non-trivial cost, so it is memoized
/// per [TransactionType]; the per-call [ColorScheme.copyWith] over the base is
/// cheap. This means flipping the segment (or animating between tints) never
/// rebuilds a scheme.
final Map<TransactionType, ColorScheme> _seededSchemeCache =
    <TransactionType, ColorScheme>{};

ColorScheme _seededSchemeFor(TransactionType type) =>
    _seededSchemeCache.putIfAbsent(
      type,
      () => ColorScheme.fromSeed(
        seedColor: accentForType(type),
        brightness: Brightness.dark,
      ),
    );
