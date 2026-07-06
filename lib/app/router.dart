import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hesap_takip/features/accounts/presentation/accounts_screen.dart';
import 'package:hesap_takip/features/categories/categories_screen.dart';
import 'package:hesap_takip/features/dashboard/dashboard_screen.dart';
import 'package:hesap_takip/features/settings/settings_screen.dart';
import 'package:hesap_takip/features/transactions/presentation/transaction_form_page.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Route path constants. Kept centralized so navigation is refactor-safe.
abstract final class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String accounts = '/accounts';
  static const String categories = '/categories';
  static const String settings = '/settings';
}

/// The application's declarative router.
///
/// A [StatefulShellRoute.indexedStack] hosts the four top-level destinations,
/// each in its own navigator so per-tab state survives switching. Screens are
/// Phase 0 placeholders; deeper routes are added in later phases.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNavBar(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.accounts,
              builder: (context, state) => const AccountsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.categories,
              builder: (context, state) => const CategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Shell scaffold hosting the bottom [NavigationBar] and the active branch.
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // `initialLocation: true` re-taps return the branch to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _addTransaction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TransactionFormPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTransaction(context),
        tooltip: l10n.transactionAdd,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l10n.navAccounts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category),
            label: l10n.navCategories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
