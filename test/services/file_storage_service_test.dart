import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';

class _MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProviderPlatform(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FileStorageService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'seedling_file_storage_test_',
    );
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir.path);
    service = FileStorageService();
    await service.init();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generatePhotoPath normalizes and allowlists extensions', () async {
    final allowed = await service.generatePhotoPath(extension: 'PNG');
    final rejected = await service.generatePhotoPath(extension: '../exe');

    expect(allowed.endsWith('.png'), isTrue);
    expect(rejected.endsWith('.jpg'), isTrue);
  });

  test('generateVoicePath normalizes and allowlists extensions', () async {
    final allowed = await service.generateVoicePath(extension: 'Mp3');
    final rejected = await service.generateVoicePath(extension: 'aac;rm -rf');

    expect(allowed.endsWith('.mp3'), isTrue);
    expect(rejected.endsWith('.m4a'), isTrue);
  });

  test(
    'saveVoice falls back to safe extension for unsupported source types',
    () async {
      final source = File('${tempDir.path}/tmp.voice.unsupported');
      await source.writeAsString('audio bytes');

      final savedPath = await service.saveVoice(source.path);

      expect(savedPath, contains('/media/voices/'));
      expect(savedPath.endsWith('.m4a'), isTrue);
      expect(await File(savedPath).exists(), isTrue);
      expect(await source.exists(), isFalse);
    },
  );

  test('deleteFile blocks paths outside media directory', () async {
    final outsideFile = File('${tempDir.path}/outside.txt');
    await outsideFile.writeAsString('nope');

    final deleted = await service.deleteFile(outsideFile.path);

    expect(deleted, isFalse);
    expect(await outsideFile.exists(), isTrue);
  });

  group('stale container paths (iOS moves the app container)', () {
    const staleRoot =
        '/var/mobile/Containers/Data/Application/OLD-UUID/Library/'
        'Application Support/media';

    test('deleteFile re-anchors a stale absolute path', () async {
      final real = File(await service.generatePhotoPath());
      await real.writeAsString('pixels');
      final name = real.uri.pathSegments.last;

      final deleted = await service.deleteFile('$staleRoot/photos/$name');

      expect(deleted, isTrue);
      expect(await real.exists(), isFalse);
    });

    test('fileExists and getFileSize re-anchor stale paths', () async {
      final real = File(await service.generateVoicePath());
      await real.writeAsString('12345');
      final name = real.uri.pathSegments.last;
      final stale = '$staleRoot/voices/$name';

      expect(await service.fileExists(stale), isTrue);
      expect(await service.getFileSize(stale), 5);
    });

    test('a stale path never escapes the media directory', () async {
      final outside = File('${tempDir.path}/photos/escape.jpg');
      await outside.create(recursive: true);

      final deleted = await service.deleteFile('/elsewhere/photos/escape.jpg');

      expect(deleted, isFalse);
      expect(await outside.exists(), isTrue);
    });
  });

  test('copies into the media directory get a fresh timestamp', () async {
    final source = File('${tempDir.path}/library.jpg')
      ..writeAsStringSync('pixels')
      ..setLastModifiedSync(DateTime(2020));

    final saved = File(await service.savePhoto(source));
    final copied = await FileStorageService.copyAsNewFile(
      source,
      '${tempDir.path}/copy.jpg',
    );

    final recent = DateTime.now().subtract(const Duration(minutes: 1));
    expect(saved.lastModifiedSync().isAfter(recent), isTrue);
    expect(copied.lastModifiedSync().isAfter(recent), isTrue);
  });
}
