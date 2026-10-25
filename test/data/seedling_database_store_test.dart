// Runs against a real SQLCipher database file (package:sqlite3 bundles
// SQLCipher for host tests too).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/ritual.dart';
import 'package:seedling/data/models/sync_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SeedlingDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('seedling_db_store');
    db = await SeedlingDatabase.openForTesting(directory: dir.path);
  });

  tearDown(() async {
    db.close();
    await dir.delete(recursive: true);
  });

  test(
    'soft delete and restore bump modifiedAt so sync propagates them',
    () async {
      final store = db;
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

  test('text round-trips', () async {
    final store = db;
    final saved = await store.saveEntry(Entry.line(text: 'grandma\'s ring'));
    expect(store.getEntry(saved.id)!.text, "grandma's ring");
  });

  test('soft delete then restore keeps the tree count stable', () async {
    final store = db;
    final saved = await store.saveEntry(Entry.line(text: 'one'));
    final countBefore = store.currentTree!.entryCount;
    await store.softDeleteEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore - 1);
    await store.restoreEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore);
  });

  test('tree counts follow isDeleted on every write path', () async {
    final store = db;
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

  test('manual links survive a reopen', () async {
    final store = db;
    final saved = await store.saveEntry(
      Entry.line(text: 'river walk')
        ..manualLinkIds = '550e8400-e29b-41d4-a716-446655440001',
    );
    store.close();
    final reopened = await SeedlingDatabase.openForTesting(directory: dir.path);
    db = reopened;
    expect(
      reopened.getEntry(saved.id)!.manualLinkIds,
      '550e8400-e29b-41d4-a716-446655440001',
    );
  });

  test('saveEntry assigns a v4 syncUUID when missing', () async {
    final store = db;
    final saved = await store.saveEntry(Entry.line(text: 'no id yet'));
    expect(SyncId.isValid(saved.syncUUID), isTrue);
    expect(store.getEntry(saved.id)!.syncUUID, saved.syncUUID);
  });

  group('read integrity', () {
    test('UTC timestamps read back as local time and count in the local '
        'year', () async {
      final store = db;
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
      final saved = await store.saveEntry(Entry.line(text: 'original'));

      // Every read builds fresh objects: mutating one never reaches what
      // later reads return.
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

  test('saveEntries writes a batch in one emit and counts once', () async {
    var emits = 0;
    final sub = db.watchEntries().skip(1).listen((_) => emits++);
    final countBefore = db.currentTree!.entryCount;

    final saved = await db.saveEntries([
      for (var i = 0; i < 20; i++) Entry.line(text: 'batch $i'),
      Entry.line(text: 'already let go')..isDeleted = true,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(saved.every((e) => e.id != 0), isTrue);
    expect(emits, 1);
    // The soft-deleted one must not grow the tree.
    expect(db.currentTree!.entryCount, countBefore + 20);
    expect(db.getAllEntries(), hasLength(20));
    await sub.cancel();
  });

  test('a failing batch writes nothing', () async {
    const uuid = '6f1c2a34-5b6d-4e7f-8a9b-0c1d2e3f4a5b';
    await db.saveEntry(Entry.line(text: 'first')..syncUUID = uuid);
    final countBefore = db.currentTree!.entryCount;

    // syncUUID is UNIQUE: a second row with the same identity is refused.
    await expectLater(
      db.saveEntries([
        Entry.line(text: 'fine'),
        Entry.line(text: 'clash')..syncUUID = uuid,
      ]),
      throwsA(anything),
    );
    expect(db.getAllEntries().map((e) => e.text), ['first']);
    expect(db.currentTree!.entryCount, countBefore);
  });

  test('reads match a freshly opened database after mixed writes', () async {
    final a = await db.saveEntry(Entry.line(text: 'a'));
    final b = await db.saveEntry(Entry.line(text: 'b'));
    final c = await db.saveEntry(Entry.line(text: 'c'));
    final held = db.getEntry(a.id)!..text = 'a, edited';
    db.updateEntry(held);
    // Mutating a returned object without saving must not leak into reads.
    db.getEntry(b.id)!.text = 'never saved';
    await db.softDeleteEntry(b.id);
    await db.deleteEntry(c.id);

    List<String?> snapshot(SeedlingDatabase d) => [
      ...d.getAllEntries().map((e) => e.text),
      '|',
      ...d.getDeletedEntries().map((e) => e.text),
      '|',
      d.currentTree!.entryCount.toString(),
    ];

    final before = snapshot(db);
    db.close();
    db = await SeedlingDatabase.openForTesting(directory: dir.path);
    expect(snapshot(db), before);
    expect(before, ['a, edited', '|', 'b', '|', '1']);
  });

  test('purge removes expired trash and reports it for sync', () async {
    final old = await db.saveEntry(
      Entry.line(text: 'long gone')
        ..isDeleted = true
        ..deletedAt = DateTime.now().subtract(const Duration(days: 31)),
    );
    await db.saveEntry(
      Entry.line(text: 'recent')
        ..isDeleted = true
        ..deletedAt = DateTime.now().subtract(const Duration(days: 2)),
    );

    expect(await db.purgeExpiredEntries(), 1);
    expect(db.getEntry(old.id), isNull);
    expect(db.getDeletedEntries().map((e) => e.text), ['recent']);
    expect(db.takePurgedEntries().single.syncUUID, old.syncUUID);
    expect(db.takePurgedEntries(), isEmpty);
    expect(db.searchEntryIds('long gone'), isEmpty);
  });

  group('full-text search', () {
    test('matches substrings of text, title, context and transcription, '
        'ignoring case and accents', () async {
      final line = await db.saveEntry(Entry.line(text: 'Coffee at the Café'));
      final titled = await db.saveEntry(
        Entry.object(title: "Grandma's ring", text: 'from the attic'),
      );
      final voice = await db.saveEntry(
        Entry.voice(mediaPath: 'voices/a.m4a')
          ..transcription = 'we walked along the river',
      );
      final placed = await db.saveEntry(
        Entry.line(text: 'quiet')..context = 'Lisbon, by the sea',
      );

      expect(db.searchEntryIds('cafe'), {line.id});
      expect(db.searchEntryIds('OFFEE'), {line.id});
      expect(db.searchEntryIds('grandma'), {titled.id});
      expect(db.searchEntryIds('along the riv'), {voice.id});
      expect(db.searchEntryIds('lisbon'), {placed.id});
      expect(db.searchEntryIds('nothing like this'), isEmpty);
      // Too short for the trigram index: the caller matches in memory.
      expect(db.searchEntryIds('ri'), isNull);
      // Quotes and FTS syntax are taken literally.
      expect(db.searchEntryIds('"ring" OR *'), isEmpty);
    });

    test('follows edits and deletes', () async {
      final saved = await db.saveEntry(Entry.line(text: 'morning swim'));
      expect(db.searchEntryIds('swim'), {saved.id});

      db.updateEntry(db.getEntry(saved.id)!..text = 'evening walk');
      expect(db.searchEntryIds('swim'), isEmpty);
      expect(db.searchEntryIds('walk'), {saved.id});

      await db.deleteEntry(saved.id);
      expect(db.searchEntryIds('walk'), isEmpty);
    });
  });

  test('rituals round-trip, sorted by name, and are watched', () async {
    final ritual = Ritual(
      name: 'Coffee with Dad at the hospital',
      signature: 'coffee|dad|hospital@morning',
    );
    await db.saveRitual(ritual);
    await db.saveRitual(Ritual(name: 'Bread on Sundays', signature: 'bread'));
    expect(ritual.id, isNot(0));

    final read = db.getRitual(ritual.id)!;
    expect(read.name, 'Coffee with Dad at the hospital');
    expect(read.signature, 'coffee|dad|hospital@morning');
    expect(read.uuid, ritual.uuid);
    expect(db.getAllRituals().map((r) => r.name), [
      'Bread on Sundays',
      'Coffee with Dad at the hospital',
    ]);

    read.occurrenceCount = 3;
    await db.saveRitual(read);
    expect(db.getRitual(ritual.id)!.occurrenceCount, 3);
    expect((await db.watchRituals().first), hasLength(2));

    await db.deleteRitual(ritual.id);
    expect(db.getAllRituals().single.name, 'Bread on Sundays');
  });

  test('works in memory too', () async {
    final memory = await SeedlingDatabase.openForTesting();
    addTearDown(memory.close);
    await memory.saveEntry(Entry.line(text: 'ephemeral'));
    expect(memory.getAllEntries().single.text, 'ephemeral');
    expect(memory.isFreshStore, isTrue);
  });
}
