import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hesap_takip/app/router.dart';
import 'package:hesap_takip/app/theme/app_theme.dart';
import 'package:hesap_takip/core/undo/undo_service.dart';
import 'package:hesap_takip/features/recurring/application/recurring_providers.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Root application widget.
///
/// Dark theme ONLY (PROJECT_PLAN §10.1): `themeMode` is fixed to
/// [ThemeMode.dark] and only [AppTheme.dark] is supplied — there is no light
/// theme and no `ThemeMode.system`. The runtime UI is Turkish; `tr` is the sole
/// supported locale.
///
/// It is also the undo SAFETY NET (§8.5): an [AppLifecycleListener] flushes any
/// pending undo actions to Drift before the isolate can die.
class HesapTakipApp extends ConsumerStatefulWidget {
  const HesapTakipApp({super.key});

  @override
  ConsumerState<HesapTakipApp> createState() => _HesapTakipAppState();
}

class _HesapTakipAppState extends ConsumerState<HesapTakipApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleStateChange,
    );
  }

  void _onLifecycleStateChange(AppLifecycleState state) {
    // `paused` is the RELIABLE flush point: the app is backgrounded but the
    // isolate is still alive and can await the DB writes to completion. On
    // `detached` the OS may kill us at any moment, so we flush there too but
    // only best-effort. Committing here means a pending destructive action is
    // never lost when the app leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(undoServiceProvider).flushAllNow();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cold-start recurring generation, fire-and-forget (§B.5). A local SQLite
    // batch, so the first frame is NOT gated on it — we just kick it off and let
    // the list repaint reactively as rows land.
    ref.watch(recurringGenerationProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
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
