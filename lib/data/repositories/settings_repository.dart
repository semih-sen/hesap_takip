import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../models/mappers/settings_mapper.dart';
import '../models/settings.dart';

part 'settings_repository.g.dart';

/// Reactive data API for the singleton app settings, returning the DOMAIN
/// [Settings] model.
abstract interface class SettingsRepository {
  /// The settings row, re-emitting on every change.
  Stream<Settings> watchSettings();

  /// The current settings row.
  Future<Settings> getSettings();

  /// Sets the base currency (affects only NEW transactions; §6).
  Future<void> setBaseCurrency(String currencyCode);

  /// Sets the first day of the week (1 = Monday).
  Future<void> setFirstDayOfWeek(int firstDayOfWeek);
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<Settings> watchSettings() =>
      _db.settingsDao.watchSettings().map((row) => row.toDomain());

  @override
  Future<Settings> getSettings() async =>
      (await _db.settingsDao.getSettings()).toDomain();

  @override
  Future<void> setBaseCurrency(String currencyCode) =>
      _db.settingsDao.updateBaseCurrency(currencyCode);

  @override
  Future<void> setFirstDayOfWeek(int firstDayOfWeek) =>
      _db.settingsDao.updateFirstDayOfWeek(firstDayOfWeek);
}

/// App-lifetime singleton settings repository.
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    DriftSettingsRepository(ref.watch(appDatabaseProvider));

/// Reactive stream of the current [Settings].
@riverpod
Stream<Settings> settings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchSettings();

/// The base currency code derived from [settingsProvider].
///
/// Falls back to `'TRY'` (the seeded default) before the first settings emission
/// so dependents always have a concrete code to work with.
@riverpod
String baseCurrency(Ref ref) {
  final AsyncValue<Settings> snapshot = ref.watch(settingsProvider);
  return snapshot.asData?.value.baseCurrencyCode ?? 'TRY';
}
