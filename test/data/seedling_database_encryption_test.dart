// Whole-database encryption: the file on disk is SQLCipher ciphertext and
// opens only with its own key.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/database_key_store.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/ritual.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

Uint8List _key(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (i * 31 + seed) % 256));

/// Every byte of the database's files (main file, WAL, shared memory).
List<int> _bytesOnDisk(Directory dir) => [
  for (final f in dir.listSync().whereType<File>()) ...f.readAsBytesSync(),
];

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('seedling_db_cipher');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('SQLCipher is linked', () {
    final raw = sql.sqlite3.openInMemory();
    addTearDown(raw.close);
    final version = raw.select('PRAGMA cipher_version');
    expect(version, isNotEmpty);
    expect(version.first.values.first, isA<String>());
  });

  test('a database written with key A cannot be opened with key B', () async {
    final a = await SeedlingDatabase.openForTesting(
      directory: dir.path,
      key: _key(1),
    );
    await a.saveEntry(Entry.line(text: 'only for key A'));
    a.close();

    await expectLater(
      SeedlingDatabase.openForTesting(directory: dir.path, key: _key(2)),
      throwsA(isA<DatabaseOpenException>()),
    );

    final again = await SeedlingDatabase.openForTesting(
      directory: dir.path,
      key: _key(1),
    );
    addTearDown(again.close);
    expect(again.getAllEntries().single.text, 'only for key A');
    expect(again.isFreshStore, isFalse);
  });

  test('a plain SQLite reader sees no database at all', () async {
    final db = await SeedlingDatabase.openForTesting(
      directory: dir.path,
      key: _key(3),
    );
    await db.saveEntry(Entry.line(text: 'hello'));
    db.close();

    final raw = sql.sqlite3.open('${dir.path}/${SeedlingDatabase.fileName}');
    addTearDown(raw.close);
    expect(
      () => raw.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<sql.SqliteException>()),
    );
  });

  test('memory text never reaches the disk in plaintext', () async {
    const secret = 'Grandma whispered the recipe zx81-plaintext-probe';
    const ritualName = 'Sunday call with Dad qq42-ritual-probe';
    final db = await SeedlingDatabase.openForTesting(
      directory: dir.path,
      key: _key(4),
    );
    for (var i = 0; i < 50; i++) {
      await db.saveEntry(
        Entry.line(text: '$secret $i')
          ..title = 'title-probe-$i'
          ..transcription = 'transcript-probe-$i'
          ..mediaKey = 'media-key-probe-$i',
      );
    }
    await db.saveRitual(Ritual(name: ritualName, signature: 'dad|call'));
    // Search goes through the full-text index, which lives in the same file.
    expect(db.searchEntryIds('recipe zx81'), hasLength(50));

    // Check while open (WAL holds fresh pages) and after a checkpoint.
    var bytes = _bytesOnDisk(dir);
    expect(bytes, isNotEmpty);
    for (final probe in ['zx81-plaintext-probe', 'qq42-ritual-probe']) {
      expect(_contains(bytes, utf8.encode(probe)), isFalse, reason: probe);
    }
    db.close();
    bytes = _bytesOnDisk(dir);
    for (final probe in [
      'zx81-plaintext-probe',
      'title-probe',
      'transcript-probe',
      'media-key-probe',
      'qq42-ritual-probe',
      'SQLite format 3',
    ]) {
      expect(_contains(bytes, utf8.encode(probe)), isFalse, reason: probe);
    }
  });

  group('SeedlingDatabase.create', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('creates one key and reuses it', () async {
      final keys = DatabaseKeyStore();
      final first = await SeedlingDatabase.create(
        keyStore: keys,
        directory: dir.path,
      );
      expect(first.isFreshStore, isTrue);
      await first.saveEntry(Entry.line(text: 'kept'));
      final key = await keys.read();
      expect(key, hasLength(32));
      first.close();

      final second = await SeedlingDatabase.create(
        keyStore: keys,
        directory: dir.path,
      );
      addTearDown(second.close);
      expect(await keys.read(), key);
      expect(second.isFreshStore, isFalse);
      expect(second.getAllEntries().single.text, 'kept');
    });

    test('a file whose key is gone is set aside, not overwritten', () async {
      final first = await SeedlingDatabase.openForTesting(
        directory: dir.path,
        key: _key(5),
      );
      await first.saveEntry(Entry.line(text: 'unreachable'));
      first.close();

      final db = await SeedlingDatabase.create(
        keyStore: DatabaseKeyStore(),
        directory: dir.path,
      );
      addTearDown(db.close);
      expect(db.getAllEntries(), isEmpty);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.any((n) => n.contains('.unreadable-')), isTrue);
    });
  });
}
