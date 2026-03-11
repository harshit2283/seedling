import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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
}
