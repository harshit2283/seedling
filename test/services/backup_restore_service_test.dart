import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/backup/backup_restore_service.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

class _MockObjectBoxDatabase extends Mock implements ObjectBoxDatabase {}

class _MockFileStorageService extends Mock implements FileStorageService {}

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
}
