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
}
