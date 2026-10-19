import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/export/export_service.dart';
import 'package:seedling/core/services/export/safe_zip.dart';

Uint8List buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, bytes) {
    archive.add(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Rewrites the declared uncompressed size of [name] in the central
/// directory, simulating a crafted archive that lies about its size.
Uint8List patchDeclaredSize(Uint8List zip, String name, int size) {
  final data = ByteData.sublistView(zip);
  for (var i = 0; i + 46 < zip.length; i++) {
    if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
    final nameLen = data.getUint16(i + 28, Endian.little);
    final entryName = utf8.decode(zip.sublist(i + 46, i + 46 + nameLen));
    if (entryName == name) {
      data.setUint32(i + 24, size, Endian.little);
      return zip;
    }
  }
  throw StateError('entry $name not found');
}

const _tiny = SafeZipLimits(
  maxEntries: 5,
  maxTotalBytes: 1024 * 1024,
  maxEntryBytes: 512 * 1024,
);

void main() {
  test('reads entries back intact (stored and deflated)', () {
    final text = utf8.encode('hello ' * 1000);
    final zip = buildZip({
      'a.txt': text,
      'dir/b.bin': [1, 2, 3],
    });
    final reader = SafeZipReader.fromBytes(zip);
    expect(reader.files.map((e) => e.name), ['a.txt', 'dir/b.bin']);
    expect(reader.readBytes(reader.find('a.txt')!), text);
    expect(reader.readBytes(reader.find('dir/b.bin')!), [1, 2, 3]);
    reader.close();
  });

  test('rejects an entry that inflates beyond its declared size', () {
    final zip = patchDeclaredSize(
      buildZip({'bomb.bin': Uint8List(4 * 1024 * 1024)}),
      'bomb.bin',
      1000,
    );
    final reader = SafeZipReader.fromBytes(zip);
    expect(
      () => reader.readBytes(reader.find('bomb.bin')!),
      throwsA(isA<UnsafeArchiveException>()),
    );
  });

  test('rejects declared sizes over the cap before inflating anything', () {
    final zip = patchDeclaredSize(
      buildZip({'a.bin': Uint8List(10)}),
      'a.bin',
      600 * 1024,
    );
    expect(
      () => SafeZipReader.fromBytes(zip, limits: _tiny),
      throwsA(isA<UnsafeArchiveException>()),
    );
  });

  test('rejects too many entries', () {
    final zip = buildZip({
      for (var i = 0; i < 6; i++) 'f$i.txt': const [1],
    });
    expect(
      () => SafeZipReader.fromBytes(zip, limits: _tiny),
      throwsA(isA<UnsafeArchiveException>()),
    );
  });

  for (final name in [
    '../evil.txt',
    'media/../../evil.txt',
    '/etc/passwd',
    r'..\evil.txt',
    'C:/evil.txt',
  ]) {
    test('rejects zip-slip name "$name"', () {
      final zip = buildZip({
        name: const [1],
      });
      expect(
        () => SafeZipReader.fromBytes(zip),
        throwsA(isA<UnsafeArchiveException>()),
      );
    });
  }

  test('rejects garbage and truncated input', () {
    expect(
      () => SafeZipReader.fromBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
    final zip = buildZip({'a.txt': utf8.encode('x' * 5000)});
    expect(
      () => SafeZipReader.fromBytes(Uint8List.sublistView(zip, 0, 100)),
      throwsA(isA<FormatException>()),
    );
  });

  test('extractTo streams to disk and removes partial output on failure', () {
    final dir = Directory.systemTemp.createTempSync('safe_zip_extract');
    addTearDown(() => dir.deleteSync(recursive: true));
    final ok = buildZip({'ok.bin': List.generate(200000, (i) => i % 7)});
    final reader = SafeZipReader.fromBytes(ok);
    reader.extractTo(reader.find('ok.bin')!, '${dir.path}/out/ok.bin');
    expect(File('${dir.path}/out/ok.bin').lengthSync(), 200000);

    final bomb = patchDeclaredSize(
      buildZip({'bomb.bin': Uint8List(1024 * 1024)}),
      'bomb.bin',
      10,
    );
    final bad = SafeZipReader.fromBytes(bomb);
    expect(
      () => bad.extractTo(bad.find('bomb.bin')!, '${dir.path}/bomb.bin'),
      throwsA(isA<UnsafeArchiveException>()),
    );
    expect(File('${dir.path}/bomb.bin').existsSync(), isFalse);
  });

  test('resolveArchiveLink keeps links inside the archive', () {
    expect(
      resolveArchiveLink('memories/2024/03/a.md', '../../../media/p/x.jpg'),
      'media/p/x.jpg',
    );
    expect(resolveArchiveLink('a.md', '../x.jpg'), isNull);
    expect(resolveArchiveLink('a.md', '/etc/passwd'), isNull);
  });

  group('ExportService.loadZipArchive', () {
    test('rejects a media entry that lies about its size', () async {
      final entries = utf8.encode(jsonEncode({'entries': []}));
      final zip = patchDeclaredSize(
        buildZip({
          'entries.json': entries,
          'media/photos/x.jpg': Uint8List(2 * 1024 * 1024),
        }),
        'media/photos/x.jpg',
        16,
      );
      final dir = Directory.systemTemp.createTempSync('safe_zip_load');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/archive.zip';
      File(path).writeAsBytesSync(zip);

      await expectLater(
        ExportService().loadZipArchive(path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('caps JSON and Markdown entries at 64 MB declared size', () {
    final zip = patchDeclaredSize(
      buildZip({'Journal.json': utf8.encode('{}')}),
      'Journal.json',
      65 * 1024 * 1024,
    );
    expect(
      () => SafeZipReader.fromBytes(zip),
      throwsA(
        isA<UnsafeArchiveException>().having(
          (e) => e.message,
          'message',
          contains('text file'),
        ),
      ),
    );
    // Media may still be large.
    final media = patchDeclaredSize(
      buildZip({
        'photos/a.jpg': const [1],
      }),
      'photos/a.jpg',
      65 * 1024 * 1024,
    );
    expect(() => SafeZipReader.fromBytes(media), returnsNormally);
  });
}
