import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'app_database_provider.g.dart';

/// Keep-alive provider owning the single [AppDatabase] instance.
///
/// Phase 1 exposes ONLY the database connection; repositories and feature
/// providers arrive in Phase 2+. The database is closed when the provider is
/// disposed (Riverpod 3: every provider receives a plain [Ref]).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
