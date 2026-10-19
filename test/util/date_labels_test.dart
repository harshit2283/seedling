import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/util/date_labels.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/tree/presentation/widgets/recent_entry_preview.dart';

void main() {
  group('DateLabels.day', () {
    test('across midnight is Yesterday, not Today', () {
      final now = DateTime(2026, 10, 19, 0, 30);
      final at = DateTime(2026, 10, 18, 20, 10); // 4h20m earlier
      expect(DateLabels.day(at, now: now), 'Yesterday');
      final label = DateLabels.dayAndTime(at, now: now, locale: 'en_US');
      expect(label, startsWith('Yesterday, 8:10'));
      expect(label, endsWith('PM'));
    });

    test('same calendar day is Today even 23 hours apart', () {
      final now = DateTime(2026, 10, 19, 23, 50);
      final at = DateTime(2026, 10, 19, 0, 5);
      expect(DateLabels.day(at, now: now), 'Today');
    });

    test('DST spring-forward (23-hour day) still counts one day', () {
      // US DST began 2026-03-08. Midnight to midnight is 23 hours in
      // zones that observe it; the label must not depend on that.
      final now = DateTime(2026, 3, 9, 0, 15);
      final at = DateTime(2026, 3, 8, 0, 20);
      expect(DateLabels.calendarDaysBetween(at, now), 1);
      expect(DateLabels.day(at, now: now), 'Yesterday');
      expect(
        DateLabels.day(DateTime(2026, 3, 8, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('DST fall-back (25-hour day) still counts one day', () {
      final now = DateTime(2026, 11, 2, 23, 50);
      final at = DateTime(2026, 11, 1, 0, 10); // ~47h40m earlier
      expect(DateLabels.calendarDaysBetween(at, now), 1);
      expect(DateLabels.day(at, now: now), 'Yesterday');
      expect(DateLabels.day(DateTime(2026, 11, 2, 0, 1), now: now), 'Today');
    });

    test('within a week shows the weekday; older shows a date', () {
      final now = DateTime(2026, 10, 19, 9); // Monday
      expect(DateLabels.day(DateTime(2026, 10, 15, 21), now: now), 'Thursday');
      expect(
        DateLabels.day(DateTime(2026, 10, 12, 21), now: now, locale: 'en_US'),
        'Oct 12',
      );
      expect(
        DateLabels.day(DateTime(2025, 10, 12), now: now, locale: 'en_US'),
        'Oct 12, 2025',
      );
      // Older entries drop the time.
      expect(
        DateLabels.dayAndTime(
          DateTime(2026, 10, 12, 21),
          now: now,
          locale: 'en_US',
        ),
        'Oct 12',
      );
    });

    test('24-hour preference', () {
      final at = DateTime(2026, 10, 19, 20, 10);
      expect(DateLabels.time(at, locale: 'en_US', use24h: true), '20:10');
    });
  });

  testWidgets('home recent row says Yesterday for last night', (tester) async {
    final now = DateTime.now();
    // Yesterday, a minute before midnight: under 24 hours ago for most of
    // today, which the old hours-elapsed check called "Today".
    final entry = Entry.line(text: 'Late walk')
      ..createdAt = DateTime(now.year, now.month, now.day - 1, 23, 59);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecentEntryPreview(entry: entry)),
      ),
    );
    expect(find.textContaining('Yesterday, '), findsOneWidget);
    expect(find.textContaining('Today'), findsNothing);
  });

  testWidgets('time follows the platform 24-hour setting', (tester) async {
    final now = DateTime.now();
    final entry = Entry.line(text: 'Tea')
      ..createdAt = DateTime(now.year, now.month, now.day, 0, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Scaffold(body: RecentEntryPreview(entry: entry)),
        ),
      ),
    );
    expect(find.text('Today, 00:00'), findsOneWidget);
  });
}
