import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_settings.dart';

part 'settings_dao.g.dart';

/// Data access for the singleton [AppSettings] row (always `id = 1`).
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<AppSetting> getSettings() => _singleton().getSingle();

  Future<AppSetting?> getSettingsOrNull() => _singleton().getSingleOrNull();

  Stream<AppSetting> watchSettings() => _singleton().watchSingle();

  Future<int> updateBaseCurrency(String currencyCode) => _singletonUpdate()
      .write(AppSettingsCompanion(baseCurrencyCode: Value(currencyCode)));

  Future<int> updatePrimaryCurrency(String currencyCode) => _singletonUpdate()
      .write(AppSettingsCompanion(primaryCurrencyCode: Value(currencyCode)));

  Future<int> updateFirstDayOfWeek(int firstDayOfWeek) => _singletonUpdate()
      .write(AppSettingsCompanion(firstDayOfWeek: Value(firstDayOfWeek)));

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _singleton() =>
      select(appSettings)..where((t) => t.id.equals(1));

  UpdateStatement<$AppSettingsTable, AppSetting> _singletonUpdate() =>
      update(appSettings)..where((t) => t.id.equals(1));
}
