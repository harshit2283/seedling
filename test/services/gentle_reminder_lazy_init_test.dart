import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
  });

  test('initializing never asks for notification permission', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final plugin = _MockPlugin();
    when(() => plugin.initialize(any())).thenAnswer((_) async => true);
    when(() => plugin.cancel(any())).thenAnswer((_) async {});

    final service = GentleReminderService(prefs: prefs, plugin: plugin);
    await service.reschedule(const []);

    final settings =
        verify(() => plugin.initialize(captureAny())).captured.single
            as InitializationSettings;
    expect(settings.iOS!.requestAlertPermission, isFalse);
    expect(settings.iOS!.requestSoundPermission, isFalse);
    expect(settings.iOS!.requestBadgePermission, isFalse);
  });
}
