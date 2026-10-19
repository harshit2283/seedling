import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/core/services/export/markdown_export.dart';
import 'package:seedling/core/services/export/markdown_format.dart';
import 'package:seedling/core/services/export/safe_zip.dart';
import 'package:seedling/data/models/entry.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

MarkdownExportFile fileAt(MarkdownExportPlan plan, String path) =>
    plan.files.firstWhere((f) => f.path == path);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final exportedAt = DateTime(2026, 10, 19, 9);

  group('buildMarkdownExport', () {
    test('one file per memory under memories/<year>/<month>', () {
      final plan = buildMarkdownExport([
        MarkdownExportItem(
          type: 'line',
          createdAt: DateTime(2024, 3, 5, 14, 22),
          text: 'A quiet morning',
        ),
        MarkdownExportItem(
          type: 'fragment',
          createdAt: DateTime(2025, 1, 2, 8),
        ),
      ], exportedAt: exportedAt);

      final paths = plan.files.map((f) => f.path).toList();
      expect(paths, [
        'index.md',
        'memories/2024/03/2024-03-05-1422-a-quiet-morning.md',
        'memories/2025/01/2025-01-02-0800-fragment.md',
      ]);
      expect(plan.memoryCount, 2);
    });

    test('front matter carries every field and survives hostile text', () {
      final item = MarkdownExportItem(
        type: 'photo',
        createdAt: DateTime(2024, 3, 5, 14, 22),
        title: 'He said "hi"\n---\nnot: yaml',
        text: '---\nbody with front-matter lookalike\n---',
        tags: const ['walk', 'lake'],
        theme: 'nature',
        mood: 'calm',
        syncUUID: 'abc-123',
        capsuleUnlockDate: DateTime.utc(2020, 1, 1),
        mediaSourcePath: '/media/photos/x.jpg',
        mediaFileName: 'x.jpg',
      );
      final plan = buildMarkdownExport([item], exportedAt: exportedAt);
      final md = plan.files
          .firstWhere((f) => f.path.endsWith('.md') && f.path != 'index.md')
          .content!;
      final parsed = parseFrontMatter(md);

      expect(parsed.fields['type'], 'photo');
      expect(parsed.fields['title'], item.title);
      expect(parsed.fields['tags'], ['walk', 'lake']);
      expect(parsed.fields['theme'], 'nature');
      expect(parsed.fields['mood'], 'calm');
      expect(parsed.fields['syncUUID'], 'abc-123');
      expect(parsed.fields['media'], 'media/photos/x.jpg');
      expect(
        DateTime.parse(
          parsed.fields['date'] as String,
        ).isAtSameMomentAs(DateTime(2024, 3, 5, 14, 22)),
        isTrue,
      );
      expect(
        DateTime.parse(
          parsed.fields['capsuleUnlockDate'] as String,
        ).isAtSameMomentAs(DateTime.utc(2020, 1, 1)),
        isTrue,
      );
      expect(parsed.fields.containsKey('sealed'), isFalse);
      expect(parsed.body, contains('body with front-matter lookalike'));
    });

    test('media link is relative and points at the media file', () {
      final plan = buildMarkdownExport([
        MarkdownExportItem(
          type: 'voice',
          createdAt: DateTime(2024, 3, 5),
          transcription: 'spoken words',
          mediaSourcePath: '/src/v.m4a',
          mediaFileName: 'v.m4a',
        ),
      ], exportedAt: exportedAt);
      final media = plan.files.where((f) => f.sourcePath != null).single;
      expect(media.path, 'media/voices/v.m4a');
      expect(media.sourcePath, '/src/v.m4a');

      final mdFile = plan.files.firstWhere(
        (f) => f.path.startsWith('memories/'),
      );
      final link = RegExp(
        r'\[Voice memo\]\(([^)]+)\)',
      ).firstMatch(mdFile.content!)!.group(1)!;
      expect(resolveArchiveLink(mdFile.path, link), 'media/voices/v.m4a');
      expect(mdFile.content, contains('## Transcription\n\nspoken words'));
    });

    test('sealed capsules go to capsules/ with a note and no spoilers', () {
      final plan = buildMarkdownExport([
        MarkdownExportItem(
          type: 'line',
          createdAt: DateTime(2026, 1, 1, 10),
          text: 'Secret for future me',
          capsuleUnlockDate: DateTime(2030, 6, 1),
          isSealed: true,
        ),
      ], exportedAt: exportedAt);
      final capsule = plan.files.singleWhere(
        (f) => f.path.startsWith('capsules/'),
      );
      expect(capsule.path, isNot(contains('secret')));
      expect(capsule.content, contains(MarkdownFormat.sealedNotePrefix));
      expect(capsule.content, contains('Secret for future me'));
      expect(parseFrontMatter(capsule.content!).fields['sealed'], true);

      final index = fileAt(plan, 'index.md').content!;
      expect(index, contains('## Sealed capsules'));
      expect(index, contains('Opens 1 June 2030'));
      expect(index, isNot(contains('Secret')));
    });

    test('index groups by year and month and links every memory', () {
      final plan = buildMarkdownExport([
        MarkdownExportItem(
          type: 'line',
          createdAt: DateTime(2024, 3, 5),
          text: 'Tea [with] friends',
        ),
        MarkdownExportItem(
          type: 'line',
          createdAt: DateTime(2024, 4, 1),
          title: 'April',
        ),
      ], exportedAt: exportedAt);
      final index = fileAt(plan, 'index.md').content!;
      expect(parseFrontMatter(index).fields['seedling'], 'seedling-markdown');
      expect(index, contains('## 2024'));
      expect(index, contains('### March'));
      expect(index, contains('### April'));
      expect(index, contains(r'Tea \[with\] friends'));
      for (final f in plan.files.where((f) => f.path.startsWith('memories/'))) {
        expect(index, contains('(${f.path})'));
      }
    });

    test('duplicate names get a numeric suffix', () {
      final at = DateTime(2024, 3, 5, 9);
      final plan = buildMarkdownExport([
        MarkdownExportItem(type: 'line', createdAt: at, text: 'same'),
        MarkdownExportItem(type: 'line', createdAt: at, text: 'same'),
      ], exportedAt: exportedAt);
      final paths = plan.files.map((f) => f.path).toSet();
      expect(paths, contains('memories/2024/03/2024-03-05-0900-same.md'));
      expect(paths, contains('memories/2024/03/2024-03-05-0900-same-2.md'));
    });
  });

  group('ExportService.exportToMarkdown', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('md_export');
      PathProviderPlatform.instance = _MockPathProvider(temp.path);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('writes a ZIP with markdown, index and media', () async {
      final media = Directory('${temp.path}/media')..createSync();
      File('${media.path}/photos/p.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([9, 8, 7]);
      final entries = [
        Entry.photo(
          // Stale container path: still exported.
          mediaPath: '/var/mobile/OLD/media/photos/p.jpg',
          text: 'Lake',
        )..createdAt = DateTime(2024, 3, 5, 14, 22),
        Entry.line(text: 'Words')..createdAt = DateTime(2024, 3, 6),
        Entry.capsule(text: 'Later', unlockDate: DateTime(2099, 1, 1))
          ..createdAt = DateTime(2025, 1, 1),
      ];

      final result = await ExportService().exportToMarkdown(
        entries,
        media.path,
      );
      expect(result.success, isTrue, reason: result.error);
      expect(result.filePath, contains('seedling_markdown_'));

      final reader = SafeZipReader.fromFile(result.filePath!);
      final names = reader.files.map((e) => e.name).toSet();
      expect(names, contains('index.md'));
      expect(names, contains('media/photos/p.jpg'));
      expect(
        names.where((n) => n.startsWith('memories/2024/03/')),
        hasLength(2),
      );
      expect(names.where((n) => n.startsWith('capsules/')), hasLength(1));
      expect(reader.readBytes(reader.find('media/photos/p.jpg')!), [9, 8, 7]);
      final photoMd = names.firstWhere((n) => n.contains('lake'));
      expect(
        utf8.decode(reader.readBytes(reader.find(photoMd)!)),
        contains('![Photo](../../../media/photos/p.jpg)'),
      );
      reader.close();
    });
  });
}
