import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/entry_type_usage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

class MockObjectBoxDatabase extends Mock implements ObjectBoxDatabase {}

class MockSyncEngine extends Mock implements SyncEngine {}

class MockRitualService extends Mock implements RitualService {}

class MockEntryTypeUsageService extends Mock implements EntryTypeUsageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
    registerFallbackValue(SyncChangeType.create);
    registerFallbackValue(EntryType.line);
  });

  group('EntryCreatorNotifier sync integration', () {
    late MockObjectBoxDatabase mockDb;
    late MockSyncEngine mockSyncEngine;
    late MockRitualService mockRitualService;
    late MockEntryTypeUsageService mockUsageService;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockObjectBoxDatabase();
      mockSyncEngine = MockSyncEngine();
      mockRitualService = MockRitualService();
      mockUsageService = MockEntryTypeUsageService();

      // Default stubs
      when(() => mockSyncEngine.ensureSyncUUID(any())).thenReturn(null);
      when(() => mockSyncEngine.queuePush(any(), any())).thenReturn(null);
      when(
        () => mockRitualService.updateAfterEntry(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockUsageService.recordUsage(
          any(),
          isCapsule: any(named: 'isCapsule'),
        ),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          syncEngineProvider.overrideWithValue(mockSyncEngine),
          ritualServiceProvider.overrideWithValue(mockRitualService),
          entryTypeUsageServiceProvider.overrideWithValue(mockUsageService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('createLineEntry calls ensureSyncUUID before saveEntry', () async {
      final savedEntry = Entry.line(text: 'test')..id = 1;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createLineEntry('test');

      // Verify call order: ensureSyncUUID → saveEntry → queuePush
      verifyInOrder([
        () => mockSyncEngine.ensureSyncUUID(any()),
        () => mockDb.saveEntry(any()),
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ]);
    });

    test('createPhotoEntry calls ensureSyncUUID and queuePush', () async {
      final savedEntry = Entry.photo(mediaPath: '/photo.jpg')..id = 2;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createPhotoEntry('/photo.jpg', text: 'sunset');

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test('createVoiceEntry calls ensureSyncUUID and queuePush', () async {
      final savedEntry = Entry.voice(mediaPath: '/voice.m4a')..id = 3;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createVoiceEntry('/voice.m4a');

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test('createObjectEntry calls ensureSyncUUID and queuePush', () async {
      final savedEntry = Entry.object(title: 'Ring')..id = 4;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createObjectEntry('Ring');

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test('createReleaseEntry calls ensureSyncUUID and queuePush', () async {
      final savedEntry = Entry.release(text: 'letting go')..id = 5;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createReleaseEntry('letting go');

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test('createFragmentEntry calls ensureSyncUUID and queuePush', () async {
      final savedEntry = Entry.fragment(text: 'half thought')..id = 6;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createFragmentEntry('half thought');

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test('createCapsuleEntry calls ensureSyncUUID and queuePush', () async {
      final unlockDate = DateTime.now().add(const Duration(days: 365));
      final savedEntry = Entry.capsule(text: 'future', unlockDate: unlockDate)
        ..id = 7;
      when(() => mockDb.saveEntry(any())).thenAnswer((_) async => savedEntry);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.createCapsuleEntry('future', unlockDate);

      verify(() => mockSyncEngine.ensureSyncUUID(any())).called(1);
      verify(
        () => mockSyncEngine.queuePush(savedEntry, SyncChangeType.create),
      ).called(1);
    });

    test(
      'deleteEntry re-fetches after soft delete, pushes tombstoned entry',
      () async {
        final tombstonedEntry = Entry.line(text: 'to delete')
          ..id = 10
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440010'
          ..isDeleted = true
          ..deletedAt = DateTime.now();

        when(() => mockDb.softDeleteEntry(10)).thenAnswer((_) async => true);
        when(() => mockDb.getEntry(10)).thenReturn(tombstonedEntry);

        final notifier = container.read(entryCreatorProvider.notifier);
        final result = await notifier.deleteEntry(10);

        expect(result, isTrue);
        // Verify getEntry is called AFTER softDeleteEntry to get tombstone
        verifyInOrder([
          () => mockDb.softDeleteEntry(10),
          () => mockDb.getEntry(10),
        ]);
        // Soft delete should use SyncChangeType.update with tombstoned entry
        verify(
          () =>
              mockSyncEngine.queuePush(tombstonedEntry, SyncChangeType.update),
        ).called(1);
      },
    );

    test('deleteEntry does not push sync if soft delete fails', () async {
      when(() => mockDb.softDeleteEntry(10)).thenAnswer((_) async => false);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.deleteEntry(10);

      verifyNever(() => mockSyncEngine.queuePush(any(), any()));
    });

    test(
      'permanentlyDeleteEntry grabs entry before hard delete, pushes as delete',
      () async {
        final entry = Entry.line(text: 'gone forever')
          ..id = 11
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440011';

        when(() => mockDb.getEntry(11)).thenReturn(entry);
        when(() => mockDb.deleteEntry(11)).thenAnswer((_) async => true);

        final notifier = container.read(entryCreatorProvider.notifier);
        final result = await notifier.permanentlyDeleteEntry(11);

        expect(result, isTrue);
        // Verify call order: getEntry → deleteEntry → queuePush
        verifyInOrder([
          () => mockDb.getEntry(11),
          () => mockDb.deleteEntry(11),
          () => mockSyncEngine.queuePush(entry, SyncChangeType.delete),
        ]);
      },
    );

    test(
      'permanentlyDeleteEntry does not push if entry has no syncUUID',
      () async {
        final entry = Entry.line(text: 'no uuid')..id = 12;
        // syncUUID is null

        when(() => mockDb.getEntry(12)).thenReturn(entry);
        when(() => mockDb.deleteEntry(12)).thenAnswer((_) async => true);

        final notifier = container.read(entryCreatorProvider.notifier);
        await notifier.permanentlyDeleteEntry(12);

        verifyNever(() => mockSyncEngine.queuePush(any(), any()));
      },
    );

    test('restoreEntry pushes as update after restore', () async {
      final entry = Entry.line(text: 'restored')
        ..id = 13
        ..syncUUID = '550e8400-e29b-41d4-a716-446655440013';

      when(() => mockDb.restoreEntry(13)).thenAnswer((_) async => true);
      when(() => mockDb.getEntry(13)).thenReturn(entry);

      final notifier = container.read(entryCreatorProvider.notifier);
      final result = await notifier.restoreEntry(13);

      expect(result, isTrue);
      verify(
        () => mockSyncEngine.queuePush(entry, SyncChangeType.update),
      ).called(1);
    });

    test('updateEntryText pushes as update', () async {
      final entry = Entry.line(text: 'original')
        ..id = 14
        ..syncUUID = '550e8400-e29b-41d4-a716-446655440014';

      when(() => mockDb.getEntry(14)).thenReturn(entry);
      when(() => mockDb.updateEntry(any())).thenReturn(null);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.updateEntryText(14, text: 'updated');

      verify(
        () => mockSyncEngine.queuePush(entry, SyncChangeType.update),
      ).called(1);
    });

    test('updateEntryText does nothing if entry not found', () async {
      when(() => mockDb.getEntry(99)).thenReturn(null);

      final notifier = container.read(entryCreatorProvider.notifier);
      await notifier.updateEntryText(99, text: 'nope');

      verifyNever(() => mockDb.updateEntry(any()));
      verifyNever(() => mockSyncEngine.queuePush(any(), any()));
    });
  });
}
