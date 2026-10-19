import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/tree/domain/resurfacing.dart';
import 'package:seedling/features/tree/presentation/widgets/from_your_tree_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

var _nextId = 1;

Entry _line(String text, DateTime createdAt) => Entry.line(text: text)
  ..id = _nextId++
  ..createdAt = createdAt;

void main() {
  final today = DateTime(2026, 10, 19, 9);

  group('pickResurfacedMemory', () {
    test('prefers a memory from this day in an earlier year', () {
      final entries = [
        _line('Old but not today', DateTime(2025, 1, 2)),
        _line('Two years ago today', DateTime(2024, 10, 19, 18)),
      ];
      final pick = pickResurfacedMemory(entries, today)!;
      expect(pick.entry.text, 'Two years ago today');
      expect(pick.reason, ResurfaceReason.onThisDay);
      expect(pick.yearsAgo(today), 2);
    });

    test('otherwise picks a memory at least 30 days old', () {
      final entries = [
        _line('Last week', DateTime(2026, 10, 12)),
        _line('Two months ago', DateTime(2026, 8, 10)),
      ];
      final pick = pickResurfacedMemory(entries, today)!;
      expect(pick.entry.text, 'Two months ago');
      expect(pick.reason, ResurfaceReason.fromThePast);
    });

    test('returns null when everything is recent', () {
      final entries = [
        _line('Yesterday', DateTime(2026, 10, 18)),
        _line('Earlier this month', DateTime(2026, 10, 1)),
      ];
      expect(pickResurfacedMemory(entries, today), isNull);
      expect(pickResurfacedMemory(const [], today), isNull);
    });

    test('never shows sealed capsules, trash, or released entries', () {
      final sealed = _line('Sealed', DateTime(2025, 10, 19))
        ..capsuleUnlockDate = DateTime(2030, 1, 1);
      final trashed = _line('Trashed', DateTime(2025, 10, 19))
        ..isDeleted = true
        ..deletedAt = DateTime(2026, 10, 1);
      final released = Entry.release(text: 'Let go')
        ..id = _nextId++
        ..createdAt = DateTime(2025, 10, 19);
      expect(pickResurfacedMemory([sealed, trashed, released], today), isNull);

      final opened = _line('Opened capsule', DateTime(2025, 10, 19))
        ..capsuleUnlockDate = DateTime(2026, 1, 1);
      expect(
        pickResurfacedMemory([
          sealed,
          trashed,
          released,
          opened,
        ], today)!.entry.text,
        'Opened capsule',
      );
    });

    test('is stable within a day and independent of input order', () {
      final entries = [
        for (var i = 0; i < 20; i++)
          _line('Memory $i', DateTime(2025, 1, 1).add(Duration(days: i * 9))),
      ];
      final morning = pickResurfacedMemory(entries, DateTime(2026, 10, 19, 7));
      final evening = pickResurfacedMemory(
        entries.reversed.toList(),
        DateTime(2026, 10, 19, 22),
      );
      expect(morning!.entry, same(evening!.entry));
    });

    test('rotates from day to day', () {
      final entries = [
        for (var i = 0; i < 20; i++)
          _line('Memory $i', DateTime(2025, 1, 1).add(Duration(days: i * 9))),
      ];
      final picks = {
        for (var d = 0; d < 14; d++)
          pickResurfacedMemory(
            entries,
            DateTime(2026, 10, 1).add(Duration(days: d)),
          )!.entry.text,
      };
      expect(picks.length, greaterThan(3));
    });
  });

  group('GentleReminderService resurfacing nudge', () {
    setUpAll(() {
      registerFallbackValue(const InitializationSettings());
      registerFallbackValue(const NotificationDetails());
      registerFallbackValue(tz.TZDateTime.utc(2026));
      registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
      registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('next date is the coming Sunday at 10:00', () {
      // 2026-10-19 is a Monday.
      expect(
        GentleReminderService.computeNextResurfaceDate(today),
        DateTime(2026, 10, 25, 10),
      );
      // Sunday before 10:00 -> same day; after -> next week.
      expect(
        GentleReminderService.computeNextResurfaceDate(
          DateTime(2026, 10, 25, 8),
        ),
        DateTime(2026, 10, 25, 10),
      );
      expect(
        GentleReminderService.computeNextResurfaceDate(
          DateTime(2026, 10, 25, 11),
        ),
        DateTime(2026, 11, 1, 10),
      );
    });

    Future<(GentleReminderService, _MockPlugin)> build() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plugin = _MockPlugin();
      when(() => plugin.initialize(any())).thenAnswer((_) async => true);
      when(() => plugin.cancel(any())).thenAnswer((_) async {});
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
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        ),
      ).thenAnswer((_) async {});
      return (GentleReminderService(prefs: prefs, plugin: plugin), plugin);
    }

    test('schedules a weekly, generic, lock-screen-safe nudge', () async {
      final (service, plugin) = await build();
      await service.scheduleResurfacingNudge(
        enabled: true,
        hasMemory: true,
        now: today,
      );

      final captured = verify(
        () => plugin.zonedSchedule(
          7002,
          captureAny(),
          captureAny(),
          any(),
          captureAny(),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          matchDateTimeComponents: captureAny(named: 'matchDateTimeComponents'),
        ),
      ).captured;
      expect(captured[0], 'A memory is waiting for you');
      expect(captured[1], GentleReminderService.resurfaceNotificationBody);
      final details = captured[2] as NotificationDetails;
      expect(details.android?.visibility, NotificationVisibility.private);
      expect(captured[3], DateTimeComponents.dayOfWeekAndTime);
    });

    test(
      'only cancels when disabled or when there is nothing to show',
      () async {
        final (service, plugin) = await build();
        await service.scheduleResurfacingNudge(enabled: false, hasMemory: true);
        await service.scheduleResurfacingNudge(enabled: true, hasMemory: false);

        verify(() => plugin.cancel(7002)).called(2);
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
            matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
          ),
        );
      },
    );
  });

  group('resurfaceNotificationsEnabledProvider', () {
    test('is off by default and persists the opt-in', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final plugin = _MockPlugin();
      when(() => plugin.initialize(any())).thenAnswer((_) async => true);
      when(() => plugin.cancel(any())).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allEntriesProvider.overrideWithValue(const []),
          gentleReminderServiceProvider.overrideWithValue(
            GentleReminderService(prefs: prefs, plugin: plugin),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(resurfaceNotificationsEnabledProvider), isFalse);
      await container
          .read(resurfaceNotificationsEnabledProvider.notifier)
          .setEnabled(true);
      expect(container.read(resurfaceNotificationsEnabledProvider), isTrue);
      expect(prefs.getBool(PrefsKeys.resurfaceNotificationsEnabled), isTrue);
      // Empty tree: nothing is scheduled, only cancelled.
      verify(() => plugin.cancel(7002)).called(1);
    });
  });

  group('FromYourTreeCard', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget harness(List<Entry> entries, {ValueChanged<Entry>? onOpen}) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allEntriesProvider.overrideWithValue(entries),
          resurfaceClockProvider.overrideWithValue(() => today),
        ],
        child: MaterialApp(
          home: Scaffold(body: FromYourTreeCard(onOpen: onOpen)),
        ),
      );
    }

    testWidgets('shows today\'s memory and opens it on tap', (tester) async {
      Entry? opened;
      final memory = _line('Picnic under the oak', DateTime(2025, 10, 19));
      await tester.pumpWidget(harness([memory], onOpen: (e) => opened = e));
      await tester.pumpAndSettle();

      expect(find.text('From your tree'), findsOneWidget);
      expect(find.text('Picnic under the oak'), findsOneWidget);
      expect(find.text('A year ago today'), findsOneWidget);

      await tester.tap(find.text('Picnic under the oak'));
      expect(opened, same(memory));
    });

    testWidgets('dismissing hides it for the rest of the day', (tester) async {
      final memory = _line('Picnic under the oak', DateTime(2025, 8, 3));
      await tester.pumpWidget(harness([memory]));
      await tester.pumpAndSettle();
      expect(find.text('From August 2025'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('From your tree'), findsNothing);
      expect(prefs.getString(PrefsKeys.resurfaceDismissedDate), '2026-10-19');
    });

    testWidgets('the hide button is a full 44x44 target', (tester) async {
      final semantics = tester.ensureSemantics();
      final memory = _line('Picnic under the oak', DateTime(2025, 8, 3));
      await tester.pumpWidget(harness([memory]));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.bySemanticsLabel('Hide until tomorrow'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('stays hidden when dismissed earlier today', (tester) async {
      await prefs.setString(PrefsKeys.resurfaceDismissedDate, '2026-10-19');
      await tester.pumpWidget(
        harness([_line('Picnic', DateTime(2025, 10, 19))]),
      );
      await tester.pumpAndSettle();
      expect(find.text('From your tree'), findsNothing);
    });

    testWidgets('renders nothing when nothing is old enough', (tester) async {
      await tester.pumpWidget(harness([_line('Today', today)]));
      await tester.pumpAndSettle();
      expect(find.text('From your tree'), findsNothing);
    });
  });
}
