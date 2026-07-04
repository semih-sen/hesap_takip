import 'package:flutter/widgets.dart';

/// Spacing and radius design tokens.
///
/// Use these instead of scattering raw numeric constants in widgets so the
/// layout rhythm stays consistent across the app. All values are logical
/// pixels on a 4pt base grid.
abstract final class AppSpacing {
  /// 4pt — hairline gaps, chip padding.
  static const double xs = 4;

  /// 8pt — tight vertical rhythm inside a row.
  static const double sm = 8;

  /// 12pt — default gap between related elements.
  static const double md = 12;

  /// 16pt — standard content padding / screen gutter.
  static const double lg = 16;

  /// 24pt — separation between logical sections.
  static const double xl = 24;

  /// 32pt — large empty-state / hero spacing.
  static const double xxl = 32;

  /// Standard screen edge padding.
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);
}

/// Corner-radius tokens for cards, sheets, and the bespoke list item.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static const Radius smRadius = Radius.circular(sm);
  static const Radius mdRadius = Radius.circular(md);
  static const Radius lgRadius = Radius.circular(lg);

  static const BorderRadius smAll = BorderRadius.all(smRadius);
  static const BorderRadius mdAll = BorderRadius.all(mdRadius);
  static const BorderRadius lgAll = BorderRadius.all(lgRadius);
}
