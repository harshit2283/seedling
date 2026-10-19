import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  test('exportToZip generates a file successfully', () async {
    // Create a few entries to verify functionality
    final entries = List.generate(
      10,
      (index) => Entry(
        id: index,
        text: 'Entry $index content',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    );

    final service = ExportService();

    final result = await service.exportToZip(entries, '');

    expect(result.success, true);
    expect(result.filePath, isNotNull);
    final file = File(result.filePath!);
    expect(file.existsSync(), true);
    // Clean up
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('exportToZip includes manifest and accessible HTML files', () async {
    final entries = [
      Entry(
        id: 1,
        syncUUID: 'uuid-a',
        text: 'Morning walk by the lake',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
      Entry(
        id: 2,
        text: 'Tea with a friend',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    ];

    final service = ExportService();
    final result = await service.exportToZip(entries, '');
    expect(result.success, true);
    expect(result.filePath, isNotNull);

    final file = File(result.filePath!);
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final names = archive.files.map((f) => f.name).toSet();

    expect(names.contains('entries.json'), isTrue);
    expect(names.contains('manifest.json'), isTrue);
    expect(names.contains('index.html'), isTrue);
    expect(names.any((name) => name.startsWith('entries/entry-')), isTrue);

    final loaded = await service.loadZipArchive(result.filePath!);
    expect(loaded.entries.length, entries.length);
    expect(loaded.preview.entryCount, entries.length);

    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('exportEncryptedBackup and importEncryptedBackup roundtrip', () async {
    final entries = List.generate(
      4,
      (index) => Entry(
        id: index,
        text: 'Encrypted entry $index',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    );

    final service = ExportService();
    final exportResult = await service.exportEncryptedBackup(
      entries,
      '',
      passphrase: 'correct horse battery staple',
    );

    expect(exportResult.success, true);
    expect(exportResult.filePath, isNotNull);

    final importResult = await service.importEncryptedBackup(
      exportResult.filePath!,
      passphrase: 'correct horse battery staple',
    );

    expect(importResult.success, true);
    expect(importResult.importedEntries, entries.length);
    expect(importResult.importedMediaFiles, 0);

    final loaded = await service.loadEncryptedBackup(
      exportResult.filePath!,
      passphrase: 'correct horse battery staple',
    );
    expect(loaded.preview.entryCount, entries.length);
    expect(loaded.preview.version, 1);

    final file = File(exportResult.filePath!);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('exportEncryptedBackup does not leave a plaintext zip behind', () async {
    final entries = [
      Entry(
        id: 99,
        text: 'Sensitive export',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    ];

    final tempDir = Directory.systemTemp;
    final before = tempDir
        .listSync()
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.zip'))
        .toSet();

    final service = ExportService();
    final exportResult = await service.exportEncryptedBackup(
      entries,
      '',
      passphrase: 'no plaintext zip',
    );

    expect(exportResult.success, true);
    expect(exportResult.filePath, isNotNull);

    final after = tempDir
        .listSync()
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.zip'))
        .toSet();

    expect(after, equals(before));

    final file = File(exportResult.filePath!);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('importEncryptedBackup fails with wrong passphrase', () async {
    final entries = [
      Entry(
        id: 1,
        text: 'Secret memory',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    ];

    final service = ExportService();
    final exportResult = await service.exportEncryptedBackup(
      entries,
      '',
      passphrase: 'right-passphrase',
    );

    expect(exportResult.success, true);
    expect(exportResult.filePath, isNotNull);

    final importResult = await service.importEncryptedBackup(
      exportResult.filePath!,
      passphrase: 'wrong-passphrase',
    );

    expect(importResult.success, false);
    expect(importResult.error, contains('Invalid passphrase'));

    final file = File(exportResult.filePath!);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('loadEncryptedBackup rejects invalid metadata', () async {
    final entries = [
      Entry(
        id: 2,
        text: 'Encrypted invalid test',
        createdAt: DateTime.now(),
        typeIndex: EntryType.line.index,
      ),
    ];

    final service = ExportService();
    final exportResult = await service.exportEncryptedBackup(
      entries,
      '',
      passphrase: 'metadata-passphrase',
    );

    expect(exportResult.success, true);
    final file = File(exportResult.filePath!);
    final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    payload['iterations'] = 100;
    file.writeAsStringSync(jsonEncode(payload));

    await expectLater(
      service.loadEncryptedBackup(
        exportResult.filePath!,
        passphrase: 'metadata-passphrase',
      ),
      throwsA(isA<FormatException>()),
    );

    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('exportToZip includes media whose stored path went stale', () async {
    final mediaRoot = await Directory.systemTemp.createTemp('export_media');
    try {
      final photo = File('${mediaRoot.path}/photos/abc.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      expect(photo.existsSync(), isTrue);
      final entry = Entry.photo(
        mediaPath:
            '/var/mobile/Containers/Data/Application/OLD/Library/'
            'Application Support/media/photos/abc.jpg',
      )..id = 7;

      final service = ExportService();
      final result = await service.exportToZip([entry], mediaRoot.path);
      expect(result.success, isTrue);

      final archive = ZipDecoder().decodeBytes(
        File(result.filePath!).readAsBytesSync(),
      );
      final media = archive.files.where(
        (f) => f.name == 'media/photos/abc.jpg',
      );
      expect(media, hasLength(1));
      expect(media.first.content, [1, 2, 3]);
      File(result.filePath!).deleteSync();
    } finally {
      mediaRoot.deleteSync(recursive: true);
    }
  });

  group('encrypted backup KDF hardening', () {
    test('new backups use 600k PBKDF2 iterations', () async {
      final service = ExportService();
      final result = await service.exportEncryptedBackup(
        [Entry.line(text: 'kdf')],
        '',
        passphrase: 'a strong passphrase',
      );
      expect(result.success, isTrue);
      final file = File(result.filePath!);
      final payload = jsonDecode(file.readAsStringSync()) as Map;
      expect(payload['iterations'], 600000);
      file.deleteSync();
    });

    test(
      'import rejects an absurd iteration count without running the KDF',
      () async {
        final service = ExportService(kdfIterations: 100000);
        final result = await service.exportEncryptedBackup(
          [Entry.line(text: 'kdf')],
          '',
          passphrase: 'a strong passphrase',
        );
        final file = File(result.filePath!);
        final payload = jsonDecode(file.readAsStringSync()) as Map;
        payload['iterations'] = 2000000000;
        file.writeAsStringSync(jsonEncode(payload));

        final sw = Stopwatch()..start();
        await expectLater(
          service.loadEncryptedBackup(
            file.path,
            passphrase: 'a strong passphrase',
          ),
          throwsA(isA<FormatException>()),
        );
        expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
        file.deleteSync();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('unlocking runs off the UI isolate', () async {
      final service = ExportService(kdfIterations: 300000);
      final result = await service.exportEncryptedBackup(
        [Entry.line(text: 'responsive')],
        '',
        passphrase: 'a strong passphrase',
      );
      final path = result.filePath!;

      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => ticks++,
      );
      final sw = Stopwatch()..start();
      final loaded = await service.loadEncryptedBackup(
        path,
        passphrase: 'a strong passphrase',
      );
      timer.cancel();
      expect(loaded.entries, hasLength(1));
      // The event loop kept turning while the KDF ran: roughly one tick per
      // 10ms. A main-isolate KDF would starve the timer completely.
      expect(ticks, greaterThan(sw.elapsedMilliseconds ~/ 40));
      File(path).deleteSync();
    });
  });

  group('remote media link (pending downloads)', () {
    Entry pendingPhoto() => Entry.photo(mediaPath: '', text: 'on the way')
      ..mediaPath = null
      ..syncUUID = 'u-pending'
      ..mediaAssetId = 'asset-1'
      ..mediaKey = 'secret-key';

    test('encrypted backup keeps mediaAssetId and mediaKey', () async {
      final service = ExportService(kdfIterations: 100000);
      final result = await service.exportEncryptedBackup(
        [pendingPhoto()],
        '',
        passphrase: 'a strong passphrase',
      );
      expect(result.success, isTrue, reason: result.error);
      final loaded = await service.loadEncryptedBackup(
        result.filePath!,
        passphrase: 'a strong passphrase',
      );
      expect(loaded.entries.single['mediaAssetId'], 'asset-1');
      expect(loaded.entries.single['mediaKey'], 'secret-key');
      File(result.filePath!).deleteSync();
    });

    test('plaintext exports never carry the media key', () async {
      final service = ExportService();
      final json = await service.exportToJson([pendingPhoto()]);
      expect(
        File(json.filePath!).readAsStringSync(),
        isNot(contains('secret-key')),
      );
      File(json.filePath!).deleteSync();

      final zip = await service.exportToZip([pendingPhoto()], '');
      final archive = ZipDecoder().decodeBytes(
        File(zip.filePath!).readAsBytesSync(),
      );
      for (final f in archive.files) {
        expect(
          utf8.decode(f.content, allowMalformed: true),
          isNot(contains('secret-key')),
          reason: f.name,
        );
      }
      File(zip.filePath!).deleteSync();
    });

    test('pendingMediaWarning explains what the export will miss', () {
      expect(ExportService.pendingMediaWarning(0, encrypted: true), isNull);
      expect(
        ExportService.pendingMediaWarning(3, encrypted: false),
        contains('3 photos or voice memos'),
      );
      expect(
        ExportService.pendingMediaWarning(1, encrypted: true),
        contains('keeps the link'),
      );
    });
  });

  group('exports that restore could not read fail clearly', () {
    late Directory media;

    setUp(() => media = Directory.systemTemp.createTempSync('big_media'));
    tearDown(() => media.deleteSync(recursive: true));

    Entry sparsePhoto(String name, int bytes) {
      final file = File('${media.path}/photos/$name')
        ..createSync(recursive: true);
      // Sparse: the size check only reads the length.
      file.openSync(mode: FileMode.write)
        ..truncateSync(bytes)
        ..closeSync();
      return Entry.photo(mediaPath: file.path);
    }

    test('encrypted backup over the 300 MB restore cap', () async {
      final result = await ExportService(kdfIterations: 100000)
          .exportEncryptedBackup(
            [sparsePhoto('a.jpg', 240 * 1024 * 1024)],
            media.path,
            passphrase: 'a strong passphrase',
          );
      expect(result.success, isFalse);
      expect(result.error, contains('more than an encrypted backup can hold'));
      expect(result.error, contains('Nothing was lost'));
    });

    test('ZIP over the 800 MB restore cap', () async {
      final result = await ExportService().exportToZip([
        sparsePhoto('a.jpg', 450 * 1024 * 1024),
        sparsePhoto('b.jpg', 450 * 1024 * 1024),
      ], media.path);
      expect(result.success, isFalse);
      expect(result.error, contains('more than a ZIP backup can hold'));
    });

    test('Markdown export with a file over the per-file cap', () async {
      final result = await ExportService().exportToMarkdown([
        sparsePhoto('a.jpg', 513 * 1024 * 1024),
      ], media.path);
      expect(result.success, isFalse);
      expect(result.error, contains('larger than one Markdown export'));
    });
  });
}
