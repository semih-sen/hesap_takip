import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/data/database/app_database.dart' as db;
import 'package:hesap_takip/data/database/app_database_provider.dart';
import 'package:hesap_takip/data/database/tables/enums.dart';
import 'package:hesap_takip/features/accounts/presentation/accounts_screen.dart';
import 'package:hesap_takip/l10n/generated/app_localizations.dart';

/// Minimal host so [AccountsScreen] has localizations and Material ancestors.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AccountsScreen(),
    );
  }
}

void main() {
  testWidgets('accounts screen shows the empty state, then a seeded account', (
    WidgetTester tester,
  ) async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Host()),
    );

    // Drive Drift's real-async stream so it emits its first (empty) value.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    expect(find.text('Henüz hesap yok'), findsOneWidget);

    // Seed an account; the stream should push it into the list.
    await tester.runAsync(
      () => database.accountDao.createAccount(
        db.AccountsCompanion.insert(
          name: 'Günlük Hesap',
          type: AccountType.cash,
          colorValue: 0xFF12B5A5,
          iconCodePoint: 0xE000,
          sortOrder: const Value(0),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();

    expect(find.text('Günlük Hesap'), findsOneWidget);
    // Its (empty) wallet section renders too.
    expect(find.text('Bu hesapta cüzdan yok.'), findsOneWidget);
  });
}
