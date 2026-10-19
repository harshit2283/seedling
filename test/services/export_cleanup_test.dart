import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/core/services/export/export_cleanup.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:share_plus/share_plus.dart';

class _MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('export_cleanup_test');
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('shareAndDelete', () {
    test(
      'deletes the plaintext export after the share sheet returns',
      () async {
        String? sharedPath;
        final service = ExportService(
          shareFile: (XFile file, {String? subject, Rect? origin}) async {
            sharedPath = file.path;
            expect(File(file.path).existsSync(), isTrue);
          },
        );
        final result = await service.exportToJson([Entry.line(text: 'secret')]);
        expect(result.success, isTrue);

        await service.shareAndDelete(result.filePath!);

        expect(sharedPath, result.filePath);
        expect(File(result.filePath!).existsSync(), isFalse);
      },
    );

    test('deletes the export even when sharing throws', () async {
      final service = ExportService(
        shareFile: (XFile file, {String? subject, Rect? origin}) async {
          throw StateError('share sheet failed');
        },
      );
      final result = await service.exportToZip([Entry.line(text: 'x')], '');
      expect(result.success, isTrue);

      await expectLater(
        service.shareAndDelete(result.filePath!),
        throwsStateError,
      );
      expect(File(result.filePath!).existsSync(), isFalse);
    });
  });

  group('sweepStaleExportArtifacts', () {
    File touch(String relative, DateTime modified) {
      final file = File('${tempDir.path}/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('plaintext');
      file.setLastModifiedSync(modified);
      return file;
    }

    test('removes stale exports and share leftovers, keeps fresh '
        'and unrelated files', () async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(hours: 2));
      final fresh = now.subtract(const Duration(minutes: 5));

      final staleJson = touch('seedling_export_2024.json', old);
      final staleZip = touch('seedling_backup_2024.zip', old);
      final staleMd = touch('seedling_markdown_2024.zip', old);
      final staleIntake = touch('shared_intake/abc/photo.jpg', old);
      final staleSharePlus = touch('share_plus/seedling_backup_x.zip', old);
      final freshExport = touch('seedling_export_now.json', fresh);
      final freshIntake = touch('shared_intake/new.jpg', fresh);
      final unrelated = touch('other_cache_file.bin', old);

      final deleted = await sweepStaleExportArtifacts(tempDir, now: now);

      expect(deleted, 5);
      for (final f in [
        staleJson,
        staleZip,
        staleMd,
        staleIntake,
        staleSharePlus,
      ]) {
        expect(f.existsSync(), isFalse, reason: f.path);
      }
      expect(freshExport.existsSync(), isTrue);
      expect(freshIntake.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);
    });

    test('is a no-op for a missing directory', () async {
      final missing = Directory('${tempDir.path}/does_not_exist');
      expect(await sweepStaleExportArtifacts(missing), 0);
    });
  });
}
