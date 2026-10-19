import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/backup/backup_restore_service.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_models.dart';

class _MockObjectBoxDatabase extends Mock implements ObjectBoxDatabase {}

class _MockFileStorageService extends Mock implements FileStorageService {}

class _MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  setUpAll(() {
    registerFallbackValue(Entry());
  });

  late Directory tempDir;
  late _MockObjectBoxDatabase database;
  late _MockFileStorageService fileStorage;
  late List<Entry> saved;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restore_test');
    database = _MockObjectBoxDatabase();
    fileStorage = _MockFileStorageService();
    saved = [];

    var counter = 0;
    when(
      () => fileStorage.generatePhotoPath(extension: any(named: 'extension')),
    ).thenAnswer((inv) async {
      final ext = inv.namedArguments[#extension] as String;
      return '${tempDir.path}/photo_${counter++}.$ext';
    });
    when(() => fileStorage.clearAllMedia()).thenAnswer((_) async {
      // Mirror the real behaviour: wipe the whole media directory.
      for (final f in tempDir.listSync()) {
        f.deleteSync(recursive: true);
      }
    });

    when(
      () => database.getAllEntries(),
    ).thenReturn([Entry.line(text: 'old memory')..id = 1]);
    when(() => database.softDeleteEntry(any())).thenAnswer((_) async => true);
    when(() => database.saveEntry(any())).thenAnswer((inv) async {
      final entry = inv.positionalArguments.first as Entry;
      saved.add(entry);
      return entry;
    });
    when(() => database.recountTrees()).thenAnswer((_) async {});
    when(
      () => database.getDeletedEntries(),
    ).thenReturn([Entry.line(text: 'old memory')..id = 1]);
    when(() => database.deleteEntry(any())).thenAnswer((_) async => true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  LoadedEncryptedBackup backupWithPhoto() {
    return LoadedEncryptedBackup(
      preview: const EncryptedBackupPreview(
        entryCount: 1,
        mediaCount: 1,
        version: 1,
      ),
      entries: [
        {
          'type': 'photo',
          'createdAt': '2025-05-01T10:00:00.000Z',
          'modifiedAt': '2025-05-02T10:00:00.000Z',
          'text': 'beach',
          'mediaPath': 'media/photos/abc.jpg',
          'transcription': 'waves',
          'manualLinkIds': 'uuid-a,uuid-b',
          'syncUUID': 'uuid-photo',
        },
      ],
      mediaFiles: {
        'media/photos/abc.jpg': [1, 2, 3, 4],
      },
    );
  }

  test('replace mode keeps the media files it just restored', () async {
    final service = BackupRestoreService(
      database: database,
      fileStorage: fileStorage,
    );

    final result = await service.restore(
      backupWithPhoto(),
      mode: BackupImportMode.replace,
    );

    expect(result.success, isTrue);
    expect(result.importedMediaFiles, 1);
    expect(saved, hasLength(1));
    final restoredPath = saved.single.mediaPath!;
    expect(File(restoredPath).existsSync(), isTrue);
    expect(File(restoredPath).readAsBytesSync(), [1, 2, 3, 4]);
    verifyNever(() => fileStorage.clearAllMedia());
    verify(() => database.deleteEntry(1)).called(1);
  });

  test('restores fields the exporter writes', () async {
    final service = BackupRestoreService(
      database: database,
      fileStorage: fileStorage,
    );

    await service.restore(backupWithPhoto(), mode: BackupImportMode.merge);

    final entry = saved.single;
    expect(entry.transcription, 'waves');
    expect(entry.manualLinkIds, 'uuid-a,uuid-b');
    expect(entry.syncUUID, 'uuid-photo');
    expect(entry.modifiedAt, DateTime.parse('2025-05-02T10:00:00.000Z'));
  });

  test('merge mode skips entries already present', () async {
    final existing = Entry.photo(mediaPath: '/x.jpg', text: 'beach')
      ..createdAt = DateTime.parse('2025-05-01T10:00:00.000Z');
    when(() => database.getAllEntries()).thenReturn([existing]);
    final service = BackupRestoreService(
      database: database,
      fileStorage: fileStorage,
    );

    final result = await service.restore(
      backupWithPhoto(),
      mode: BackupImportMode.merge,
    );

    expect(result.skippedDuplicates, 1);
    expect(saved, isEmpty);
  });

  group('imports never overwrite or duplicate', () {
    BackupRestoreService service() =>
        BackupRestoreService(database: database, fileStorage: fileStorage);

    LoadedEncryptedBackup loadedWith(
      List<Map<String, dynamic>> entries, {
      Map<String, String> staged = const {},
    }) => LoadedEncryptedBackup(
      preview: EncryptedBackupPreview(
        entryCount: entries.length,
        mediaCount: staged.length,
        version: 1,
      ),
      entries: entries,
      mediaFiles: const {},
      mediaFilePaths: staged,
    );

    test('same instant written as UTC matches a local-time entry', () async {
      final instant = DateTime.utc(2021, 5, 1, 10);
      when(
        () => database.getAllEntries(),
      ).thenReturn([Entry.line(text: 'Hello')..createdAt = instant.toLocal()]);

      final result = await service().restore(
        loadedWith([
          {
            'type': 'line',
            'createdAt': '2021-05-01T10:00:00Z',
            'text': 'Hello',
          },
        ]),
        mode: BackupImportMode.merge,
      );

      expect(result.skippedDuplicates, 1);
      expect(saved, isEmpty);
    });

    test('an entry whose syncUUID already exists is skipped, not '
        'duplicated', () async {
      when(
        () => database.getAllEntries(),
      ).thenReturn([Entry.line(text: 'original wording')..syncUUID = 'uuid-1']);

      final result = await service().restore(
        loadedWith([
          {
            'type': 'line',
            'createdAt': '2021-05-01T10:00:00Z',
            'text': 'edited elsewhere',
            'syncUUID': 'uuid-1',
          },
        ]),
        mode: BackupImportMode.merge,
      );

      expect(result.skippedDuplicates, 1);
      expect(saved, isEmpty);
    });

    test('memories in the trash are not resurrected by a merge', () async {
      when(() => database.getAllEntries()).thenReturn([]);
      when(() => database.getDeletedEntries()).thenReturn([
        Entry.line(text: 'let go')
          ..createdAt = DateTime.utc(2021, 5, 1)
          ..isDeleted = true,
      ]);

      final result = await service().restore(
        loadedWith([
          {
            'type': 'line',
            'createdAt': '2021-05-01T00:00:00Z',
            'text': 'let go',
          },
        ]),
        mode: BackupImportMode.merge,
      );
      expect(result.skippedDuplicates, 1);
    });

    test('copies media staged on disk', () async {
      final staged = File('${tempDir.path}/staged.jpg')
        ..writeAsBytesSync([5, 6, 7]);
      when(() => database.getAllEntries()).thenReturn([]);

      final result = await service().restore(
        loadedWith(
          [
            {
              'type': 'photo',
              'createdAt': '2021-05-01T10:00:00Z',
              'mediaPath': 'photos/abc.jpg',
            },
          ],
          staged: {'photos/abc.jpg': staged.path},
        ),
        mode: BackupImportMode.merge,
      );

      expect(result.importedMediaFiles, 1);
      expect(File(saved.single.mediaPath!).readAsBytesSync(), [5, 6, 7]);
    });

    test('preview counts new memories and duplicates without writing', () {
      when(() => database.getAllEntries()).thenReturn([
        Entry.line(text: 'known')..createdAt = DateTime.utc(2021, 1, 1),
      ]);
      final preview = service().preview(
        loadedWith(
          [
            {
              'type': 'line',
              'createdAt': '2021-01-01T00:00:00Z',
              'text': 'known',
            },
            {
              'type': 'line',
              'createdAt': '2021-01-02T00:00:00Z',
              'text': 'new',
            },
            {
              'type': 'line',
              'createdAt': '2021-01-02T00:00:00Z',
              'text': 'new',
            },
            {
              'type': 'photo',
              'createdAt': '2021-01-03T00:00:00Z',
              'mediaPath': 'p.jpg',
            },
          ],
          staged: {'p.jpg': '/staged/p.jpg'},
        ),
      );

      expect(preview.total, 4);
      expect(preview.duplicates, 2);
      expect(preview.newEntries, 2);
      expect(preview.mediaFiles, 1);
      verifyNever(() => database.saveEntry(any()));
    });
  });

  group('restores reach sync', () {
    setUpAll(() => registerFallbackValue(SyncChangeType.create));

    test(
      'replace returns created entries and the entries it deleted',
      () async {
        final old = Entry.line(text: 'old memory')
          ..id = 1
          ..syncUUID = 'old-uuid';
        when(() => database.getDeletedEntries()).thenReturn([old]);
        final result = await BackupRestoreService(
          database: database,
          fileStorage: fileStorage,
        ).restore(backupWithPhoto(), mode: BackupImportMode.replace);

        expect(result.createdEntries.map((e) => e.syncUUID), ['uuid-photo']);
        expect(result.deletedEntries.map((e) => e.syncUUID), ['old-uuid']);
      },
    );

    test('queueForSync pushes creates and deletes, never deleting a '
        're-created entry', () {
      final sync = _MockSyncEngine();
      final created = Entry.line(text: 'new')..syncUUID = 'same';
      final result = ImportResult.success(
        importedEntries: 1,
        importedMediaFiles: 0,
        createdEntries: [created],
        deletedEntries: [
          Entry.line(text: 'gone')..syncUUID = 'gone',
          Entry.line(text: 'old copy')..syncUUID = 'same',
        ],
      );

      BackupRestoreService.queueForSync(result, sync);

      final calls = verify(
        () => sync.queuePush(captureAny(), captureAny()),
      ).captured;
      // Pairs of (entry, change type), deletes first.
      expect(calls, hasLength(4));
      expect((calls[0] as Entry).syncUUID, 'gone');
      expect(calls[1], SyncChangeType.delete);
      expect((calls[2] as Entry).syncUUID, 'same');
      expect(calls[3], SyncChangeType.create);
    });
  });

  test('an entry whose media is still remote is restored as a pending '
      'download', () async {
    when(() => database.getAllEntries()).thenReturn([]);
    final result =
        await BackupRestoreService(
          database: database,
          fileStorage: fileStorage,
        ).restore(
          const LoadedEncryptedBackup(
            preview: EncryptedBackupPreview(
              entryCount: 1,
              mediaCount: 0,
              version: 1,
            ),
            entries: [
              {
                'type': 'photo',
                'createdAt': '2025-05-01T10:00:00.000Z',
                'text': 'still downloading',
                'mediaPath': null,
                'mediaAssetId': 'asset-1',
                'mediaKey': 'key-1',
              },
            ],
            mediaFiles: {},
          ),
          mode: BackupImportMode.merge,
        );

    final entry = saved.single;
    expect(entry.mediaAssetId, 'asset-1');
    expect(entry.mediaKey, 'key-1');
    expect(entry.mediaPath, isNull);
    expect(result.warnings, contains('media_pending_download'));
    expect(result.warnings, isNot(contains('missing_media')));
  });
}
