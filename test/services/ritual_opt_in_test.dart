// Rituals are opt-in: detection only suggests. Nothing is stored and no
// notification is scheduled until the user confirms a candidate.
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/ritual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

Future<ObjectBoxDatabase?> _tryOpen(Directory dir) async {
  try {
    return await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
  } on ArgumentError catch (e) {
    if ('$e'.contains('dynamic library')) return null;
    rethrow;
  }
}

/// Four Sunday-morning entries a week apart: a clear recurring pattern.
List<Entry> _weeklyPattern() {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day, 8);
  return [
    for (var week = 4; week >= 1; week--)
      Entry.line(text: 'pancakes garden coffee with the kids')
        ..createdAt = base.subtract(Duration(days: week * 7)),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  group('detection never creates a ritual on its own', () {
    late Directory dir;
    ObjectBoxDatabase? db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('obx_ritual_opt_in');
      db = await _tryOpen(dir);
    });

    tearDown(() async {
      db?.close();
      await dir.delete(recursive: true);
    });

    test('a detected pattern stays a suggestion until confirmed', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final service = container.read(ritualServiceProvider);

      // Save the pattern the way capture does: save, then track.
      for (final entry in _weeklyPattern()) {
        final saved = await store.saveEntry(entry);
        await service.updateAfterEntry(saved);
      }

      expect(store.getAllRituals(), isEmpty, reason: 'no silent ritual');

      container.listen(allEntriesStreamProvider, (_, _) {});
      await container.read(allEntriesStreamProvider.future);
      final detected = container.read(ritualCandidatesProvider);
      expect(detected, isNotEmpty, reason: 'the pattern is suggested');
      expect(store.getAllRituals(), isEmpty);

      // Only an explicit confirmation creates it.
      await service.createFromCandidate(
        detected.first,
        name: 'Sunday pancakes',
        cadenceDays: 7,
      );
      expect(store.getAllRituals().single.name, 'Sunday pancakes');
    });
  });

  test('reminders are only scheduled for confirmed, active rituals', () async {
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
      Ritual(name: 'unsaved candidate', signature: 'a'), // id 0
      Ritual(id: 4, name: 'paused', signature: 'b')
        ..status = RitualStatus.paused,
      Ritual(id: 5, name: 'archived', signature: 'c')
        ..status = RitualStatus.archived,
    ]);

    verifyNever(
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
    );
    verifyNever(() => plugin.initialize(any()));
  });
}
