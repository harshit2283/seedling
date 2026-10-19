// Write-path cost against a real ObjectBox store. Needs the native library
// (libobjectbox.so / .dylib) on the loader path; skipped otherwise.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AtRestEncryptionService encryption;
  ObjectBoxDatabase? db;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('obx_perf');
    encryption = AtRestEncryptionService();
    try {
      db = await ObjectBoxDatabase.openForTesting(
        directory: dir.path,
        encryptionService: encryption,
      );
    } on ArgumentError catch (e) {
      if (!'$e'.contains('dynamic library')) rethrow;
      db = null;
    }
  });

  tearDown(() async {
    db?.close();
    await dir.delete(recursive: true);
  });

  test('saving 500 entries does not re-decrypt the store per write', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    // Subscribe the way the app does (entriesStreamProvider and
    // allEntriesStreamProvider are always alive).
    final subs = <StreamSubscription<List<Entry>>>[
      store.watchEntries().listen((_) {}),
      store.watchAllEntries().listen((_) {}),
    ];

    const n = 500;
    final before = encryption.decryptCount;
    final watch = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      await store.saveEntry(Entry.line(text: 'memory $i')..title = 't$i');
    }
    // Readers that run after every write.
    store.getCurrentYearEntries();
    store.getAllEntries();
    store.getEntriesOnThisDay();
    watch.stop();
    final decrypts = encryption.decryptCount - before;
    debugPrint(
      'saved $n entries: ${watch.elapsedMilliseconds}ms, '
      '$decrypts decrypts',
    );

    // Previously every save refetched and decrypted the whole current year
    // (twice, once per stream): ~n^2 decrypts (≈500k for n=500).
    expect(decrypts, lessThan(n));
    expect(store.getAllEntries(), hasLength(n));
    expect(store.getCurrentYearEntries().first.text, 'memory ${n - 1}');

    for (final s in subs) {
      await s.cancel();
    }
  });

  test('saveEntries writes a batch in one emit and counts once', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    var emits = 0;
    final sub = store.watchEntries().skip(1).listen((_) => emits++);
    final countBefore = store.currentTree!.entryCount;

    final saved = await store.saveEntries([
      for (var i = 0; i < 20; i++) Entry.line(text: 'batch $i'),
      Entry.line(text: 'already let go')..isDeleted = true,
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(saved.every((e) => e.id != 0), isTrue);
    expect(emits, 1);
    // The soft-deleted one must not grow the tree.
    expect(store.currentTree!.entryCount, countBefore + 20);
    expect(store.getAllEntries(), hasLength(20));
    await sub.cancel();
  });

  test(
    'cached reads match a freshly opened store after mixed writes',
    () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final a = await store.saveEntry(Entry.line(text: 'a'));
      final b = await store.saveEntry(Entry.line(text: 'b'));
      final c = await store.saveEntry(Entry.line(text: 'c'));
      final held = store.getEntry(a.id)!..text = 'a, edited';
      store.updateEntry(held);
      // Mutating a returned copy without saving must not leak into reads.
      store.getEntry(b.id)!.text = 'never saved';
      await store.softDeleteEntry(b.id);
      await store.deleteEntry(c.id);

      List<String?> snapshot(ObjectBoxDatabase d) => [
        ...d.getAllEntries().map((e) => e.text),
        '|',
        ...d.getDeletedEntries().map((e) => e.text),
        '|',
        d.currentTree!.entryCount.toString(),
      ];

      final cached = snapshot(store);
      store.close();
      final reopened = await ObjectBoxDatabase.openForTesting(
        directory: dir.path,
        encryptionService: AtRestEncryptionService(),
      );
      db = reopened;
      expect(snapshot(reopened), cached);
      expect(cached, ['a, edited', '|', 'b', '|', '1']);
    },
  );
}
