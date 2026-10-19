import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/backup/backup_reminder_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/features/tree/presentation/widgets/backup_reminder_card.dart';

void main() {
  group('BackupReminderService', () {
    late SharedPreferences prefs;
    late DateTime now;
    late BackupReminderService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 10, 19, 9);
      service = BackupReminderService(prefs, clock: () => now);
    });

    /// A tree that has been growing for [days] days.
    Future<void> firstMemory(int days) => prefs.setString(
      PrefsKeys.firstMemorySeenAt,
      now.subtract(Duration(days: days)).toIso8601String(),
    );

    test('no reminder when no entries exist', () {
      expect(service.shouldShowReminder(entryCount: 0), false);
    });

    test('never on day one, even with many memories', () {
      // Old behaviour: no backup date => reminder right away.
      expect(service.shouldShowReminder(entryCount: 5), false);
      expect(service.shouldShowReminder(entryCount: 40), false);
    });

    test('first memory is remembered the first time it is seen', () {
      expect(service.getFirstMemorySeenAt(), isNull);
      service.shouldShowReminder(entryCount: 1);
      expect(service.getFirstMemorySeenAt(), now);
      // Later calls keep the original date.
      now = now.add(const Duration(days: 3));
      service.shouldShowReminder(entryCount: 2);
      expect(service.getFirstMemorySeenAt(), DateTime(2026, 10, 19, 9));
    });

    test('waits for 14 days since the first memory', () async {
      await firstMemory(13);
      expect(service.shouldShowReminder(entryCount: 20), false);
      await firstMemory(14);
      expect(service.shouldShowReminder(entryCount: 20), true);
    });

    test('waits for 10 memories', () async {
      await firstMemory(60);
      expect(service.shouldShowReminder(entryCount: 9), false);
      expect(service.shouldShowReminder(entryCount: 10), true);
    });

    test('day-one tree grows into a suggestion two weeks later', () {
      expect(service.shouldShowReminder(entryCount: 12), false);
      now = now.add(const Duration(days: 14));
      expect(service.shouldShowReminder(entryCount: 12), true);
    });

    test('no reminder when backup was recent (< 30 days)', () async {
      await firstMemory(90);
      await service.recordBackup();
      now = now.add(const Duration(days: 29));
      expect(service.shouldShowReminder(entryCount: 10), false);
      now = now.add(const Duration(days: 1));
      expect(service.shouldShowReminder(entryCount: 10), true);
    });

    test('dismiss silences reminder for 30 days', () async {
      await firstMemory(90);
      expect(service.shouldShowReminder(entryCount: 15), true);
      await service.dismissReminder();
      expect(service.shouldShowReminder(entryCount: 15), false);
      now = now.add(const Duration(days: 29));
      expect(service.shouldShowReminder(entryCount: 15), false);
      now = now.add(const Duration(days: 1));
      expect(service.shouldShowReminder(entryCount: 15), true);
    });

    test('recordBackup resets the timer and clears dismissal', () async {
      await firstMemory(90);
      await service.dismissReminder();
      await service.recordBackup();
      expect(service.shouldShowReminder(entryCount: 15), false);
      expect(service.getLastBackupDate(), now);
      expect(prefs.getString(PrefsKeys.backupReminderDismissedAt), isNull);
    });

    test('getLastBackupDate returns null when never backed up', () {
      expect(service.getLastBackupDate(), isNull);
    });

    test('handles corrupted date strings gracefully', () async {
      await prefs.setString(PrefsKeys.lastBackupDate, 'not-a-date');
      expect(service.getLastBackupDate(), isNull);
    });
  });

  testWidgets('home line uses the warm copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          shouldShowBackupReminderProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: Scaffold(body: BackupReminderCard())),
      ),
    );
    expect(
      find.textContaining('Keep a copy of your memories somewhere safe'),
      findsOneWidget,
    );
    expect(find.textContaining('No backup in a while'), findsNothing);
  });
}
