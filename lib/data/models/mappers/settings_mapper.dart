import '../../database/app_database.dart' as db;
import '../settings.dart';

/// Mapper from the Drift `AppSettings` row to the [Settings] domain model.
///
/// Writes go through dedicated `SettingsDao` setters (base currency, first day
/// of week), so no companion mapper is needed here.
extension AppSettingRowMapper on db.AppSetting {
  Settings toDomain() => Settings(
    baseCurrencyCode: baseCurrencyCode,
    firstDayOfWeek: firstDayOfWeek,
  );
}
