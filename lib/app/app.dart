import 'package:flutter/material.dart';
import 'package:hesap_takip/app/router.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Root application widget.
///
/// Dark theme ONLY (PROJECT_PLAN §10.1): `themeMode` is fixed to
/// [ThemeMode.dark] and only [AppTheme.dark] is supplied — there is no light
/// theme and no `ThemeMode.system`. The runtime UI is Turkish; `tr` is the sole
/// supported locale.
class HesapTakipApp extends StatelessWidget {
  const HesapTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
    );
  }
}
