import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';

void main() {
  group('GentleReminderService.computeNextReminderDate', () {
    test('returns null when disabled', () {
      final next = GentleReminderService.computeNextReminderDate(
        now: DateTime(2026, 2, 22, 10, 0),
        lastActivity: DateTime(2026, 2, 21, 9, 0),
        settings: const ReminderSettings.defaults(),
      );
      expect(next, isNull);
    });

    test('weekly cadence schedules after last activity', () {
      final settings = const ReminderSettings.defaults().copyWith(
        enabled: true,
        cadence: ReminderCadence.weekly,
        hour: 19,
        minute: 30,
      );

      final next = GentleReminderService.computeNextReminderDate(
        now: DateTime(2026, 2, 22, 10, 0),
        lastActivity: DateTime(2026, 2, 20, 12, 0),
        settings: settings,
      );

      expect(next, isNotNull);
      expect(next!.isAfter(DateTime(2026, 2, 27, 19, 29)), isTrue);
    });

    test('quiet hours push reminder to quiet-end hour', () {
      final settings = const ReminderSettings.defaults().copyWith(
        enabled: true,
        cadence: ReminderCadence.daily,
        hour: 22,
        minute: 15,
        quietStartHour: 21,
        quietEndHour: 8,
      );

      final next = GentleReminderService.computeNextReminderDate(
        now: DateTime(2026, 2, 22, 20, 0),
        lastActivity: null,
        settings: settings,
      );

      expect(next, isNotNull);
      expect(next!.hour, 8);
    });
  });
}
