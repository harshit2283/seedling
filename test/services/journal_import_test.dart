import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/core/services/backup/backup_restore_service.dart';
import 'package:seedling/core/services/export/export_cleanup.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/core/services/export/journal_import.dart';
import 'package:seedling/core/services/export/safe_zip.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

class _MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

class _MockDb extends Mock implements ObjectBoxDatabase {}

class _MockFileStorage extends Mock implements FileStorageService {}

Uint8List zipOf(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((n, b) => archive.add(ArchiveFile(n, b.length, b)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late _MockDb db;
  late _MockFileStorage storage;
  late List<Entry> stored;

  setUpAll(() => registerFallbackValue(Entry()));

  setUp(() {
    temp = Directory.systemTemp.createTempSync('journal_import');
    PathProviderPlatform.instance = _MockPathProvider(temp.path);
    db = _MockDb();
    storage = _MockFileStorage();
    stored = [];
    var n = 0;
    Future<String> gen(Invocation inv, String folder) async {
      final ext = inv.namedArguments[#extension] as String;
      final dir = Directory('${temp.path}/media/$folder')
        ..createSync(recursive: true);
      return '${dir.path}/restored_${n++}.$ext';
    }

    when(
      () => storage.generatePhotoPath(extension: any(named: 'extension')),
    ).thenAnswer((inv) => gen(inv, 'photos'));
    when(
      () => storage.generateVoicePath(extension: any(named: 'extension')),
    ).thenAnswer((inv) => gen(inv, 'voices'));
    when(
      () => storage.generateObjectPhotoPath(extension: any(named: 'extension')),
    ).thenAnswer((inv) => gen(inv, 'objects'));
    when(() => db.getAllEntries()).thenAnswer((_) => List.of(stored));
    when(() => db.getDeletedEntries()).thenReturn([]);
    when(() => db.saveEntry(any())).thenAnswer((inv) async {
      final e = inv.positionalArguments.first as Entry;
      e.id = stored.length + 1;
      stored.add(e);
      return e;
    });
    when(() => db.recountTrees()).thenAnswer((_) async {});
  });

  tearDown(() => temp.deleteSync(recursive: true));

  BackupRestoreService restorer() =>
      BackupRestoreService(database: db, fileStorage: storage);

  String writeZip(String name, Uint8List bytes) {
    final path = '${temp.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  group('Seedling Markdown round trip', () {
    test('export then import restores every memory and its media', () async {
      final mediaDir = Directory('${temp.path}/live_media')..createSync();
      final photo = File('${mediaDir.path}/photos/a.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final voice = File('${mediaDir.path}/voices/v.m4a')
        ..createSync(recursive: true)
        ..writeAsBytesSync([4, 5]);

      final originals = <Entry>[
        Entry.line(text: 'A line\nwith two lines', mood: 'calm')
          ..createdAt = DateTime(2024, 3, 5, 14, 22, 7, 123)
          ..tags = 'walk,lake'
          ..detectedTheme = 'nature'
          ..syncUUID = 'u-line',
        Entry.photo(mediaPath: photo.path, text: 'Lake photo')
          ..createdAt = DateTime(2024, 3, 6),
        Entry.voice(mediaPath: voice.path, text: 'Note')
          ..createdAt = DateTime(2024, 4, 1)
          ..transcription = 'spoken words',
        Entry.object(title: "Grandma's ring", text: 'Story')
          ..createdAt = DateTime(2023, 12, 24),
        Entry.release(text: 'Letting go')..createdAt = DateTime(2023, 1, 1),
        Entry.capsule(text: 'Future me', unlockDate: DateTime.utc(2099))
          ..createdAt = DateTime(2025, 6, 1),
      ];

      final service = ExportService();
      final export = await service.exportToMarkdown(originals, mediaDir.path);
      expect(export.success, isTrue, reason: export.error);

      final import = await service.loadJournalArchive(export.filePath!);
      expect(import.source, JournalImportSource.seedlingMarkdown);
      expect(import.backup.entries, hasLength(originals.length));
      expect(import.skipped, 0);

      final preview = restorer().preview(import.backup);
      expect(preview.newEntries, originals.length);
      expect(preview.mediaFiles, 2);

      final result = await restorer().restore(
        import.backup,
        mode: BackupImportMode.merge,
      );
      expect(result.importedEntries, originals.length);
      expect(result.importedMediaFiles, 2);
      await service.discardJournalImport(import);
      expect(Directory(import.stagingDirectory).existsSync(), isFalse);

      Entry find(EntryType type) => stored.firstWhere((e) => e.type == type);
      final line = find(EntryType.line);
      expect(line.text, 'A line\nwith two lines');
      expect(line.mood, 'calm');
      expect(line.tags, 'walk,lake');
      expect(line.detectedTheme, 'nature');
      expect(line.syncUUID, 'u-line');
      expect(
        line.createdAt.isAtSameMomentAs(DateTime(2024, 3, 5, 14, 22, 7, 123)),
        isTrue,
      );

      final restoredPhoto = find(EntryType.photo);
      expect(restoredPhoto.text, 'Lake photo');
      expect(File(restoredPhoto.mediaPath!).readAsBytesSync(), [1, 2, 3]);

      final restoredVoice = find(EntryType.voice);
      expect(restoredVoice.text, 'Note');
      expect(restoredVoice.transcription, 'spoken words');
      expect(File(restoredVoice.mediaPath!).readAsBytesSync(), [4, 5]);

      final object = find(EntryType.object);
      expect(object.title, "Grandma's ring");
      expect(object.text, 'Story');

      expect(find(EntryType.release).isReleased, isTrue);

      final capsule = stored.firstWhere((e) => e.isCapsule);
      expect(capsule.text, 'Future me');
      expect(
        capsule.capsuleUnlockDate!.isAtSameMomentAs(DateTime.utc(2099)),
        isTrue,
      );

      // Importing the same export again adds nothing.
      final again = await service.loadJournalArchive(export.filePath!);
      expect(restorer().preview(again.backup).newEntries, 0);
      await service.discardJournalImport(again);
    });

    test('tolerates Obsidian-edited front matter and skips plain notes', () {
      final map = parseSeedlingMarkdown(
        '---\n'
        'date: 2024-03-05T14:22:00+01:00\n'
        'type: line\n'
        'title: \'It\'\'s fine\'\n'
        'tags:\n'
        '  - walk\n'
        '  - lake\n'
        '---\n'
        '\n'
        "# It's fine\n"
        '\n'
        'Edited in Obsidian.\n',
        archivePath: 'memories/2024/03/x.md',
        mediaExists: (_) => false,
      )!;
      expect(map['title'], "It's fine");
      expect(map['tags'], 'walk,lake');
      expect(map['text'], 'Edited in Obsidian.');
      expect(map['createdAt'], '2024-03-05T13:22:00.000Z');

      expect(
        parseSeedlingMarkdown(
          '# Just a note\n',
          archivePath: 'a.md',
          mediaExists: (_) => true,
        ),
        isNull,
      );
    });

    test('a photo whose media is missing keeps its words as a line', () {
      final map = parseSeedlingMarkdown(
        '---\ndate: 2024-01-01T00:00:00Z\ntype: photo\n'
        'media: "media/photos/gone.jpg"\n---\n\nStill here\n\n'
        '![Photo](../../../media/photos/gone.jpg)\n',
        archivePath: 'memories/2024/01/a.md',
        mediaExists: (_) => false,
      )!;
      expect(map['type'], 'line');
      expect(map['mediaPath'], isNull);
      expect(map['text'], contains('Still here'));
    });

    test('links that escape the archive are never followed', () {
      final map = parseSeedlingMarkdown(
        '---\ndate: 2024-01-01T00:00:00Z\ntype: photo\n'
        'media: "../../etc/passwd"\n---\n\n![x](../../../../etc/passwd)\n',
        archivePath: 'memories/2024/01/a.md',
        mediaExists: (_) => true,
      )!;
      expect(map['mediaPath'], isNull);
    });
  });

  group('Day One import', () {
    Map<String, dynamic> journal(List<Map<String, dynamic>> entries) => {
      'metadata': {'version': '1.0'},
      'entries': entries,
    };

    test('maps entries, media, tags, location and titles', () async {
      final zip = zipOf({
        'Journal.json': utf8.encode(
          jsonEncode(
            journal([
              {
                'uuid': 'A',
                'creationDate': '2021-05-01T10:00:00Z',
                'text': '# Morning walk\n\nSaw a heron\\. Lovely\\!',
                'tags': ['nature', 'walk'],
                'starred': true,
                'location': {
                  'placeName': 'Lakeside',
                  'localityName': 'Zurich',
                  'country': 'Switzerland',
                },
              },
              {
                'uuid': 'B',
                'creationDate': '2021-05-02T10:00:00Z',
                'text': '![](dayone-moment://P1)\n\nBeach day',
                'photos': [
                  {'identifier': 'P1', 'md5': 'aaa111', 'type': 'jpeg'},
                ],
              },
              {
                'uuid': 'C',
                'creationDate': '2021-05-03T10:00:00Z',
                'text': 'Trip',
                'photos': [
                  {'md5': 'bbb222', 'type': 'jpeg', 'orderInEntry': 1},
                  {'md5': 'aaa111', 'type': 'jpeg', 'orderInEntry': 0},
                  {'md5': 'missing', 'type': 'jpeg', 'orderInEntry': 2},
                ],
                'audios': [
                  {'md5': 'ccc333', 'format': 'm4a'},
                ],
              },
              {
                'uuid': 'D',
                'creationDate': '2021-05-04T10:00:00Z',
                'text': '![](dayone-moment:/audio/X)',
                'audios': [
                  {'md5': 'ccc333', 'format': 'm4a'},
                ],
              },
              {'uuid': 'E', 'creationDate': '2021-05-05T10:00:00Z', 'text': ''},
              {'uuid': 'F', 'text': 'no date'},
            ]),
          ),
        ),
        'photos/aaa111.jpeg': [1, 1, 1],
        'photos/bbb222.jpeg': [2, 2, 2],
        'audios/ccc333.m4a': [3, 3, 3],
      });

      final service = ExportService();
      final import = await service.loadJournalArchive(writeZip('d1.zip', zip));
      expect(import.source, JournalImportSource.dayOne);
      expect(import.skipped, 2); // empty + undated
      expect(import.backup.warnings, contains('missing_media'));

      final result = await restorer().restore(
        import.backup,
        mode: BackupImportMode.merge,
      );
      await service.discardJournalImport(import);
      expect(result.importedEntries, 6);

      final walk = stored.firstWhere((e) => e.title == 'Morning walk');
      expect(walk.type, EntryType.line);
      expect(walk.text, 'Saw a heron. Lovely!');
      expect(walk.tags, 'nature,walk,starred');
      expect(walk.context, 'Lakeside, Zurich, Switzerland');
      expect(
        walk.createdAt.isAtSameMomentAs(DateTime.utc(2021, 5, 1, 10)),
        isTrue,
      );

      final beach = stored.firstWhere((e) => e.text == 'Beach day');
      expect(beach.type, EntryType.photo);
      expect(File(beach.mediaPath!).readAsBytesSync(), [1, 1, 1]);

      final trip = stored.where((e) => e.createdAt.toUtc().day == 3).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(trip.map((e) => e.type), [
        EntryType.photo,
        EntryType.photo,
        EntryType.voice,
      ]);
      expect(trip.first.text, 'Trip');
      expect(File(trip[0].mediaPath!).readAsBytesSync(), [1, 1, 1]);
      expect(File(trip[1].mediaPath!).readAsBytesSync(), [2, 2, 2]);
      expect(trip[1].title, 'Day One · 2 of 3');
      expect(trip[1].text, isNull);

      final voiceOnly = stored.firstWhere((e) => e.createdAt.toUtc().day == 4);
      expect(voiceOnly.type, EntryType.voice);
      expect(voiceOnly.text, isNull);

      // Re-importing the same export is a no-op.
      final again = await service.loadJournalArchive(writeZip('d2.zip', zip));
      final preview = restorer().preview(again.backup);
      expect(preview.newEntries, 0);
      expect(preview.duplicates, 6);
      await service.discardJournalImport(again);
    });

    test('rejects zip-slip names before extracting anything', () async {
      final zip = zipOf({
        'Journal.json': utf8.encode(jsonEncode(journal([]))),
        '../../evil.sh': utf8.encode('rm -rf /'),
      });
      await expectLater(
        ExportService().loadJournalArchive(writeZip('slip.zip', zip)),
        throwsA(isA<UnsafeArchiveException>()),
      );
      expect(File('${temp.path}/../evil.sh').existsSync(), isFalse);
      expect(
        temp.listSync().whereType<Directory>().where(
          (d) => d.path.contains(importStagingPrefix),
        ),
        isEmpty,
      );
    });

    test('rejects a photo that inflates beyond its declared size', () async {
      final zip = zipOf({
        'Journal.json': utf8.encode(
          jsonEncode(
            journal([
              {
                'creationDate': '2021-05-02T10:00:00Z',
                'photos': [
                  {'md5': 'bomb', 'type': 'jpeg'},
                ],
              },
            ]),
          ),
        ),
        'photos/bomb.jpeg': Uint8List(3 * 1024 * 1024),
      });
      // Lie about the size in the central directory.
      final data = ByteData.sublistView(zip);
      for (var i = 0; i + 46 < zip.length; i++) {
        if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
        final len = data.getUint16(i + 28, Endian.little);
        if (utf8.decode(zip.sublist(i + 46, i + 46 + len)) ==
            'photos/bomb.jpeg') {
          data.setUint32(i + 24, 100, Endian.little);
        }
      }
      await expectLater(
        ExportService().loadJournalArchive(writeZip('bomb.zip', zip)),
        throwsA(isA<UnsafeArchiveException>()),
      );
    });

    test('a ZIP that is neither format is refused', () async {
      final zip = zipOf({'notes.txt': utf8.encode('hello')});
      await expectLater(
        ExportService().loadJournalArchive(writeZip('other.zip', zip)),
        throwsA(isA<FormatException>()),
      );
    });

    test('cleanDayOneText strips moments and markdown escapes', () {
      expect(
        cleanDayOneText(
          'Hi\\! 1\\. item\n\n\n\n![](dayone-moment://X)\nend \\- ok',
        ),
        'Hi! 1. item\n\nend - ok',
      );
    });
  });

  test('startup sweep removes stale import staging directories', () async {
    final stale = Directory('${temp.path}/${importStagingPrefix}1')
      ..createSync();
    File('${stale.path}/m0.jpg').writeAsBytesSync([1]);
    final fresh = Directory('${temp.path}/${importStagingPrefix}2')
      ..createSync();
    await Process.run('touch', ['-t', '202001010000', stale.path]);

    await sweepStaleExportArtifacts(temp);

    expect(stale.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });
}
