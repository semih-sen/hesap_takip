import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';

/// Domain model for the singleton app settings row (PROJECT_PLAN §5.2).
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    required String baseCurrencyCode,
    required String primaryCurrencyCode,
    required int firstDayOfWeek,
  }) = _Settings;
}
