import 'package:flutter_test/flutter_test.dart';
import 'package:hesap_takip/core/date/app_date.dart';

void main() {
  group('AppDate.lastDayOfMonth', () {
    test('common months', () {
      expect(AppDate.lastDayOfMonth(2026, 1), 31); // Jan
      expect(AppDate.lastDayOfMonth(2026, 4), 30); // Apr
      expect(AppDate.lastDayOfMonth(2026, 12), 31); // Dec
    });

    test('February leap vs non-leap', () {
      expect(AppDate.lastDayOfMonth(2024, 2), 29); // leap
      expect(AppDate.lastDayOfMonth(2026, 2), 28); // non-leap
      expect(AppDate.lastDayOfMonth(2000, 2), 29); // century leap
      expect(AppDate.lastDayOfMonth(1900, 2), 28); // century non-leap
    });
  });

  group('AppDate.addMonthsClamped', () {
    test('monthly-on-31st marches without permanent drift (non-leap 2026)', () {
      // The rule day is always 31 (dayOverride), so each step derives the day
      // FRESH — Feb clamps to 28, but March snaps back to 31.
      DateTime d = DateTime(2026, 1, 31);
      d = AppDate.addMonthsClamped(d, 1, dayOverride: 31);
      expect(d, DateTime(2026, 2, 28)); // Feb clamps
      d = AppDate.addMonthsClamped(d, 1, dayOverride: 31);
      expect(d, DateTime(2026, 3, 31)); // snaps back to 31
      d = AppDate.addMonthsClamped(d, 1, dayOverride: 31);
      expect(d, DateTime(2026, 4, 30)); // Apr clamps
      d = AppDate.addMonthsClamped(d, 1, dayOverride: 31);
      expect(d, DateTime(2026, 5, 31));
    });

    test('leap year February is 29', () {
      final DateTime d = AppDate.addMonthsClamped(
        DateTime(2024, 1, 31),
        1,
        dayOverride: 31,
      );
      expect(d, DateTime(2024, 2, 29));
    });

    test('no drift when clamped repeatedly across a year', () {
      // Without dayOverride the day would drift; WITH it (the rule contract),
      // 31 is preserved wherever the month allows.
      DateTime d = DateTime(2026, 1, 31);
      for (int i = 0; i < 12; i++) {
        d = AppDate.addMonthsClamped(d, 1, dayOverride: 31);
      }
      // 12 steps from Jan 2026 → Jan 2027, day 31 preserved.
      expect(d, DateTime(2027, 1, 31));
    });

    test('year roll-over (December + 1)', () {
      expect(
        AppDate.addMonthsClamped(DateTime(2026, 12, 15), 1),
        DateTime(2027, 1, 15),
      );
    });

    test('yearly interval (12 months) clamps Feb 29 → Feb 28', () {
      expect(
        AppDate.addMonthsClamped(DateTime(2024, 2, 29), 12, dayOverride: 29),
        DateTime(2025, 2, 28),
      );
    });

    test('negative months roll the year back correctly', () {
      expect(
        AppDate.addMonthsClamped(DateTime(2026, 1, 15), -1),
        DateTime(2025, 12, 15),
      );
      expect(
        AppDate.addMonthsClamped(DateTime(2026, 3, 31), -1, dayOverride: 31),
        DateTime(2026, 2, 28),
      );
    });
  });
}
