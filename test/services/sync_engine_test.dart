import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_metadata.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockObjectBoxDatabase extends Mock implements ObjectBoxDatabase {}

class _MockSyncBackend extends Mock implements SyncBackend {}

class _MockSyncCryptoService extends Mock implements SyncCryptoService {}

class _FakeSyncEncryptionSession extends Fake
    implements SyncEncryptionSession {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Entry());
    registerFallbackValue(_FakeSyncEncryptionSession());
  });

  group('SyncEngine', () {
    late _MockObjectBoxDatabase database;
    late _MockSyncBackend backend;
    late _MockSyncCryptoService crypto;

    setUp(() {
      database = _MockObjectBoxDatabase();
      backend = _MockSyncBackend();
      crypto = _MockSyncCryptoService();
      when(
        () => crypto.createEncryptionSession(),
      ).thenAnswer((_) async => _FakeSyncEncryptionSession());
      when(
        () => crypto.encryptRecordFields(any(), session: any(named: 'session')),
      ).thenAnswer((invocation) async {
        final record = Map<String, dynamic>.from(
          invocation.positionalArguments.first as Map<String, dynamic>,
        );
        record['syncEncryptionVersion'] =
            SyncCryptoService.syncEncryptionVersion;
        return record;
      });
      when(() => crypto.decryptRecordFields(any())).thenAnswer((
        invocation,
      ) async {
        return Map<String, dynamic>.from(
          invocation.positionalArguments.first as Map<String, dynamic>,
        );
      });
    });

    test('init stays disabled when metadata is disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final metadata = SyncMetadata(prefs, namespace: 'test');

      final engine = SyncEngine(
        database: database,
        backend: backend,
        metadata: metadata,
        cryptoService: crypto,
      );

      await engine.init();

      expect(engine.currentState, SyncState.disabled);
      verifyNever(() => backend.isAvailable());
    });

    test('push sends pending update and clears queue on success', () async {
      SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
      final prefs = await SharedPreferences.getInstance();
      final metadata = SyncMetadata(prefs, namespace: 'test');

      final entry = Entry.line(text: 'sync me')
        ..syncUUID = '550e8400-e29b-41d4-a716-446655440001'
        ..modifiedAt = DateTime.now();

      await metadata.addPendingChange(
        SyncChange(
          syncUUID: '550e8400-e29b-41d4-a716-446655440001',
          changeType: SyncChangeType.update,
          timestamp: DateTime.now(),
        ),
      );

      when(
        () =>
            database.getEntryBySyncUUID('550e8400-e29b-41d4-a716-446655440001'),
      ).thenReturn(entry);
      when(() => backend.saveRecord(any())).thenAnswer((_) async {});

      final engine = SyncEngine(
        database: database,
        backend: backend,
        metadata: metadata,
        cryptoService: crypto,
      );

      final result = await engine.push();

      expect(result.success, isTrue);
      expect(result.pushedCount, 1);
      expect(metadata.pendingChanges, isEmpty);
      verify(() => backend.saveRecord(any())).called(1);
      verify(
        () => crypto.encryptRecordFields(any(), session: any(named: 'session')),
      ).called(1);
      expect(engine.currentState, SyncState.idle);
    });

    test(
      'push reuses one encryption session across multiple records',
      () async {
        SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
        final prefs = await SharedPreferences.getInstance();
        final metadata = SyncMetadata(prefs, namespace: 'test');
        final sharedSession = _FakeSyncEncryptionSession();

        final firstEntry = Entry.line(text: 'first')
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440031'
          ..modifiedAt = DateTime.now();
        final secondEntry = Entry.line(text: 'second')
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440032'
          ..modifiedAt = DateTime.now();

        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440031',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );
        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440032',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );

        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440031',
          ),
        ).thenReturn(firstEntry);
        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440032',
          ),
        ).thenReturn(secondEntry);
        when(
          () => crypto.createEncryptionSession(),
        ).thenAnswer((_) async => sharedSession);
        when(() => backend.saveRecord(any())).thenAnswer((_) async {});

        final engine = SyncEngine(
          database: database,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
        );

        final result = await engine.push();

        expect(result.success, isTrue);
        verify(() => crypto.createEncryptionSession()).called(1);
        final capturedSessions = verify(
          () => crypto.encryptRecordFields(
            any(),
            session: captureAny(named: 'session'),
          ),
        ).captured;
        expect(capturedSessions, hasLength(2));
        expect(capturedSessions.first, same(sharedSession));
        expect(capturedSessions.last, same(sharedSession));
      },
    );

    test(
      'sync stores mediaPath as relative and restores absolute on pull',
      () async {
        SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
        final prefs = await SharedPreferences.getInstance();
        final metadata = SyncMetadata(prefs, namespace: 'test');
        const mediaBasePath = '/app/docs/media';

        final entry =
            Entry.photo(
                mediaPath: '/app/docs/media/photos/abc.jpg',
                text: 'photo',
              )
              ..syncUUID = '550e8400-e29b-41d4-a716-446655440101'
              ..modifiedAt = DateTime.now();

        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440101',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );

        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440101',
          ),
        ).thenReturn(entry);
        when(() => backend.saveRecord(any())).thenAnswer((_) async {});
        when(() => database.saveEntry(any())).thenAnswer((_) async => entry);
        when(
          () => backend.fetchChanges(changeToken: any(named: 'changeToken')),
        ).thenAnswer(
          (_) async => SyncFetchResult(
            records: <Map<String, dynamic>>[
              <String, dynamic>{
                'syncUUID': '550e8400-e29b-41d4-a716-446655440102',
                'typeIndex': EntryType.photo.index,
                'createdAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
                'modifiedAt': DateTime(2025, 1, 1).millisecondsSinceEpoch,
                'mediaPath': 'photos/from-remote.jpg',
                'isDeleted': false,
              },
            ],
            deletedUUIDs: const <String>[],
            newChangeToken: null,
          ),
        );

        final engine = SyncEngine(
          database: database,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
          mediaBasePath: mediaBasePath,
        );

        await engine.push();
        final capturedRecord =
            verify(() => backend.saveRecord(captureAny())).captured.single
                as Map<String, dynamic>;
        expect(capturedRecord['mediaPath'], 'photos/abc.jpg');

        await engine.pull();
        final pulledEntry =
            verify(() => database.saveEntry(captureAny())).captured.single
                as Entry;
        expect(pulledEntry.mediaPath, '/app/docs/media/photos/from-remote.jpg');
      },
    );

    test('push sends delete change to cloud service', () async {
      SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
      final prefs = await SharedPreferences.getInstance();
      final metadata = SyncMetadata(prefs, namespace: 'test');

      await metadata.addPendingChange(
        SyncChange(
          syncUUID: '550e8400-e29b-41d4-a716-446655440002',
          changeType: SyncChangeType.delete,
          timestamp: DateTime.now(),
        ),
      );

      when(
        () => backend.deleteRecord('550e8400-e29b-41d4-a716-446655440002'),
      ).thenAnswer((_) async {});

      final engine = SyncEngine(
        database: database,
        backend: backend,
        metadata: metadata,
        cryptoService: crypto,
      );

      final result = await engine.push();

      expect(result.success, isTrue);
      expect(result.pushedCount, 1);
      verify(
        () => backend.deleteRecord('550e8400-e29b-41d4-a716-446655440002'),
      ).called(1);
      expect(metadata.pendingChanges, isEmpty);
    });

    test('pull merges newer remote entry and reports conflict', () async {
      SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
      final prefs = await SharedPreferences.getInstance();
      final metadata = SyncMetadata(prefs, namespace: 'test');

      final local = Entry.line(text: 'old local')
        ..id = 10
        ..syncUUID = '550e8400-e29b-41d4-a716-446655440003'
        ..modifiedAt = DateTime(2024, 1, 1)
        ..createdAt = DateTime(2024, 1, 1);

      when(
        () =>
            database.getEntryBySyncUUID('550e8400-e29b-41d4-a716-446655440003'),
      ).thenReturn(local);
      when(() => database.updateEntry(any())).thenReturn(null);
      when(
        () => backend.fetchChanges(changeToken: any(named: 'changeToken')),
      ).thenAnswer(
        (_) async => SyncFetchResult(
          records: <Map<String, dynamic>>[
            <String, dynamic>{
              'syncUUID': '550e8400-e29b-41d4-a716-446655440003',
              'typeIndex': EntryType.line.index,
              'createdAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
              'modifiedAt': DateTime(2025, 1, 1).millisecondsSinceEpoch,
              'text': 'new remote',
              'isDeleted': false,
            },
          ],
          deletedUUIDs: const <String>[],
          newChangeToken: 'token-1',
        ),
      );

      final engine = SyncEngine(
        database: database,
        backend: backend,
        metadata: metadata,
        cryptoService: crypto,
      );

      final result = await engine.pull();

      expect(result.success, isTrue);
      expect(result.conflictsResolved, 1);
      expect(local.text, 'new remote');
      verify(() => database.updateEntry(local)).called(1);
      expect(metadata.changeToken, 'token-1');
      expect(engine.currentState, SyncState.idle);
    });

    test('pull applies remote deletions via soft delete', () async {
      SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
      final prefs = await SharedPreferences.getInstance();
      final metadata = SyncMetadata(prefs, namespace: 'test');

      final local = Entry.line(text: 'to delete')
        ..id = 77
        ..syncUUID = '550e8400-e29b-41d4-a716-446655440004';

      when(
        () =>
            database.getEntryBySyncUUID('550e8400-e29b-41d4-a716-446655440004'),
      ).thenReturn(local);
      when(() => database.softDeleteEntry(77)).thenAnswer((_) async => true);
      when(
        () => backend.fetchChanges(changeToken: any(named: 'changeToken')),
      ).thenAnswer(
        (_) async => const SyncFetchResult(
          records: <Map<String, dynamic>>[],
          deletedUUIDs: <String>['550e8400-e29b-41d4-a716-446655440004'],
          newChangeToken: null,
        ),
      );

      final engine = SyncEngine(
        database: database,
        backend: backend,
        metadata: metadata,
        cryptoService: crypto,
      );

      final result = await engine.pull();

      expect(result.success, isTrue);
      expect(result.pulledCount, 1);
      verify(() => database.softDeleteEntry(77)).called(1);
    });

    test(
      'push returns metadata error when sync passphrase is missing',
      () async {
        SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
        final prefs = await SharedPreferences.getInstance();
        final metadata = SyncMetadata(prefs, namespace: 'test');

        final entry = Entry.line(text: 'sync me')
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440011'
          ..modifiedAt = DateTime.now();

        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440011',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );
        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440011',
          ),
        ).thenReturn(entry);
        when(
          () => crypto.createEncryptionSession(),
        ).thenThrow(const SyncPassphraseMissingException());

        final engine = SyncEngine(
          database: database,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
        );

        final result = await engine.push();

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Sync passphrase is not set'));
        expect(metadata.lastError, contains('Sync passphrase is not set'));
        verifyNever(() => backend.saveRecord(any()));
      },
    );

    test(
      'push reuses one session for mixed multi-record update batches',
      () async {
        SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
        final prefs = await SharedPreferences.getInstance();
        final metadata = SyncMetadata(prefs, namespace: 'test');
        final sharedSession = _FakeSyncEncryptionSession();

        final firstEntry =
            Entry.photo(mediaPath: '/tmp/photo.jpg', text: 'photo')
              ..syncUUID = '550e8400-e29b-41d4-a716-446655440041'
              ..modifiedAt = DateTime.now();
        final secondEntry = Entry.line(text: 'note')
          ..syncUUID = '550e8400-e29b-41d4-a716-446655440042'
          ..modifiedAt = DateTime.now();

        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440041',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );
        await metadata.addPendingChange(
          SyncChange(
            syncUUID: '550e8400-e29b-41d4-a716-446655440042',
            changeType: SyncChangeType.update,
            timestamp: DateTime.now(),
          ),
        );

        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440041',
          ),
        ).thenReturn(firstEntry);
        when(
          () => database.getEntryBySyncUUID(
            '550e8400-e29b-41d4-a716-446655440042',
          ),
        ).thenReturn(secondEntry);
        when(
          () => crypto.createEncryptionSession(),
        ).thenAnswer((_) async => sharedSession);
        when(() => backend.saveRecord(any())).thenAnswer((_) async {});

        final engine = SyncEngine(
          database: database,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
        );

        final result = await engine.push();

        expect(result.success, isTrue);
        verify(() => crypto.createEncryptionSession()).called(1);
        final capturedSessions = verify(
          () => crypto.encryptRecordFields(
            any(),
            session: captureAny(named: 'session'),
          ),
        ).captured;
        expect(capturedSessions, hasLength(2));
        expect(capturedSessions.first, same(sharedSession));
        expect(capturedSessions.last, same(sharedSession));
      },
    );

    test(
      'pull returns metadata error when encrypted records cannot decrypt',
      () async {
        SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
        final prefs = await SharedPreferences.getInstance();
        final metadata = SyncMetadata(prefs, namespace: 'test');

        when(
          () => backend.fetchChanges(changeToken: any(named: 'changeToken')),
        ).thenAnswer(
          (_) async => SyncFetchResult(
            records: <Map<String, dynamic>>[
              <String, dynamic>{
                'syncUUID': '550e8400-e29b-41d4-a716-446655440020',
                'typeIndex': EntryType.line.index,
                'createdAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
                'modifiedAt': DateTime(2025, 1, 1).millisecondsSinceEpoch,
                'text': 'cipher',
                'syncEncryptionVersion': 1,
              },
            ],
            deletedUUIDs: const <String>[],
            newChangeToken: null,
          ),
        );
        when(
          () => crypto.decryptRecordFields(any()),
        ).thenThrow(const SyncPassphraseMissingException());

        final engine = SyncEngine(
          database: database,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
        );

        final result = await engine.pull();

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Sync passphrase is not set'));
        expect(metadata.lastError, contains('Sync passphrase is not set'));
      },
    );
  });
}
