import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';
import 'package:seedling/data/models/ritual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  test(
    'ritual reminders never put the ritual name on the lock screen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plugin = _MockPlugin();
      when(() => plugin.initialize(any())).thenAnswer((_) async => true);
      when(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).thenAnswer((_) async {});

      final service = GentleReminderService(prefs: prefs, plugin: plugin);
      await service.scheduleRitualReminders([
        Ritual(id: 3, name: 'Visit Mum at the hospice', signature: 's'),
      ]);

      final captured = verify(
        () => plugin.zonedSchedule(
          7103,
          captureAny(),
          captureAny(),
          any(),
          captureAny(),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).captured;

      final title = captured[0] as String?;
      final body = captured[1] as String?;
      final details = captured[2] as NotificationDetails;
      expect(title, GentleReminderService.ritualNotificationTitle);
      expect(body, GentleReminderService.ritualNotificationBody);
      expect('$title $body'.contains('Mum'), isFalse);
      expect(details.android?.visibility, NotificationVisibility.private);
    },
  );
}
