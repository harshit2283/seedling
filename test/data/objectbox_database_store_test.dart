// Runs against a real ObjectBox store. Needs the native library
// (libobjectbox.so / .dylib) on the loader path; skipped otherwise.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/sync_id.dart';

Future<ObjectBoxDatabase?> _tryOpen(Directory dir) async {
  try {
    return await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
  } on ArgumentError catch (e) {
    // Native library missing ("Failed to load dynamic library").
    if ('$e'.contains('dynamic library')) return null;
    rethrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  ObjectBoxDatabase? db;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('obx_test');
    db = await _tryOpen(dir);
  });

  tearDown(() async {
    db?.close();
    await dir.delete(recursive: true);
  });

  test(
    'soft delete and restore bump modifiedAt so sync propagates them',
    () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final saved = await store.saveEntry(Entry.line(text: 'a quiet morning'));
      final before = store.getEntry(saved.id)!.modifiedAt!;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.softDeleteEntry(saved.id);
      final afterDelete = store.getEntry(saved.id)!.modifiedAt!;
      expect(afterDelete.isAfter(before), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.restoreEntry(saved.id);
      final afterRestore = store.getEntry(saved.id)!.modifiedAt!;
      expect(afterRestore.isAfter(afterDelete), isTrue);
    },
  );

  test('text is stored encrypted and read back decrypted', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'grandma\'s ring'));
    expect(store.getEntry(saved.id)!.text, "grandma's ring");
  });

  test('soft delete then restore keeps the tree count stable', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'one'));
    final countBefore = store.currentTree!.entryCount;
    await store.softDeleteEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore - 1);
    await store.restoreEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore);
  });

  test('tree counts follow isDeleted on every write path', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final base = store.currentTree!.entryCount;
    // Arrives already in the trash (e.g. from sync): must not count.
    await store.saveEntry(Entry.line(text: 'trashed')..isDeleted = true);
    expect(store.currentTree!.entryCount, base);

    final live = await store.saveEntry(Entry.line(text: 'live'));
    expect(store.currentTree!.entryCount, base + 1);

    // Sync applies remote deletes/restores through updateEntry.
    store.updateEntry(store.getEntry(live.id)!..isDeleted = true);
    expect(store.currentTree!.entryCount, base);
    store.updateEntry(store.getEntry(live.id)!..isDeleted = false);
    expect(store.currentTree!.entryCount, base + 1);

    // Saving an already-saved entry again is not a new entry.
    await store.saveEntry(store.getEntry(live.id)!);
    expect(store.currentTree!.entryCount, base + 1);
  });

  test("updateEntry leaves the caller's object readable", () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'first light'));
    final held = store.getEntry(saved.id)!;
    held.text = 'first light, edited';
    held.title = 'dawn';
    store.updateEntry(held);

    // The object the caller still holds must stay plaintext.
    expect(held.text, 'first light, edited');
    expect(held.title, 'dawn');
    // And the stored copy round-trips.
    expect(store.getEntry(saved.id)!.text, 'first light, edited');
    expect(store.getEntry(saved.id)!.title, 'dawn');
  });

  test('manual links resolve to memories from previous years', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    const oldId = '6f1c2a34-5b6d-4e7f-8a9b-0c1d2e3f4a5b';
    const newId = '7a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
    await store.saveEntry(
      Entry.line(text: 'last summer')
        ..createdAt = DateTime(DateTime.now().year - 1, 7, 1)
        ..syncUUID = oldId,
    );
    await store.saveEntry(Entry.line(text: 'today')..syncUUID = newId);

    final linked = store.getEntriesBySyncUUIDs([oldId, newId]);
    expect(linked.map((e) => e.text), containsAll(['last summer', 'today']));
    expect(store.getEntryBySyncUUID(oldId)!.text, 'last summer');
  });

  test('connectionIds survive a reopen', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(
      Entry.line(text: 'river walk')..connectionIds = '3,7',
    );
    store.close();
    final reopened = await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
    db = reopened;
    expect(reopened.getEntry(saved.id)!.connectionIds, '3,7');
  });

  test('saveEntry assigns a v4 syncUUID when missing', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'no id yet'));
    expect(SyncId.isValid(saved.syncUUID), isTrue);
    expect(store.getEntry(saved.id)!.syncUUID, saved.syncUUID);
  });

  group('cache integrity', () {
    test('UTC timestamps are cached as local time and counted in the local '
        'year', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      // 22:00 on New Year's Eve, local time, handed in as UTC (importers and
      // sync do this).
      final instant = DateTime(2024, 12, 31, 22).toUtc();
      final entry = Entry.line(text: 'fireworks')
        ..createdAt = instant
        ..capsuleUnlockDate = DateTime.utc(2020)
        ..deletedAt = null;
      await store.saveEntry(entry);

      final cached = store.getEntry(entry.id)!;
      expect(cached.createdAt.isUtc, isFalse);
      expect(cached.capsuleUnlockDate!.isUtc, isFalse);
      expect(cached.createdAt.isAtSameMomentAs(instant), isTrue);
      expect(store.getTreeForYear(2024)?.entryCount, 1);
      expect(store.getTreeForYear(2025)?.entryCount ?? 0, 0);
    });

    test('returned entries are copies; lists are read-only', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final saved = await store.saveEntry(Entry.line(text: 'original'));

      // List views are shared read-only snapshots of copies: mutating an
      // element never reaches the plaintext cache that reads/writes use.
      store.getAllEntries().first.text = 'mutated';
      store.getCurrentYearEntries().first.text = 'mutated';
      store.getEntriesPage(limit: 10, offset: 0).first.text = 'mutated';
      store.getDeletedEntries();

      expect(store.getEntry(saved.id)!.text, 'original');
      expect(store.getEntriesPage(limit: 10, offset: 0).first.text, 'original');
      expect(store.getEntryBySyncUUID(saved.syncUUID!)!.text, 'original');
      expect(
        () => store.getAllEntries().add(Entry.line(text: 'x')),
        throwsUnsupportedError,
      );
    });

    test('a capsule that unlocks mid-session becomes visible without a '
        'write', () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      await store.saveEntry(
        Entry.capsule(
          text: 'soon',
          unlockDate: DateTime.now().add(const Duration(milliseconds: 300)),
        ),
      );
      expect(
        store.getCurrentYearEntries().where((e) => e.text == 'soon'),
        isEmpty,
      );

      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(
        store.getCurrentYearEntries().where((e) => e.text == 'soon'),
        hasLength(1),
      );
    });
  });
}
