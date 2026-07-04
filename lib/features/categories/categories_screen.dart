import 'package:flutter/material.dart';
import 'package:hesap_takip/app/theme/app_colors.dart';
import 'package:hesap_takip/app/theme/app_spacing.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Phase 0 placeholder for the categories screen.
/// Hierarchical income/expense categories arrive in Phase 4 (PROJECT_PLAN §10.2).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.category_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.placeholderComingSoon,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
