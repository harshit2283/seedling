import 'package:drift/drift.dart';

part 'schema.g.dart';

// The on-disk schema of Seedling's SQLite (SQLCipher) database, version 1.
//
// Timestamps are INTEGER milliseconds since the Unix epoch (an instant, no
// time zone); `SeedlingDatabase` turns them into local DateTimes on read.
// Column names are drift's snake_case of the getters below.

/// Memories. One row per [Entry].
@DataClassName('EntryRow')
@TableIndex(name: 'entries_created_at', columns: {#createdAt})
@TableIndex(name: 'entries_modified_at', columns: {#modifiedAt})
// Leads with is_deleted so "live memories, newest first" (most screens)
// reads straight off the index: no sort, and LIMIT stops early.
@TableIndex(
  name: 'entries_is_deleted_created_at',
  columns: {#isDeleted, #createdAt},
)
@TableIndex(name: 'entries_capsule_unlock_date', columns: {#capsuleUnlockDate})
@TableIndex(name: 'entries_type_index', columns: {#typeIndex})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAt => integer()();
  IntColumn get typeIndex => integer().withDefault(const Constant(0))();
  TextColumn get textContent => text().named('text').nullable()();
  TextColumn get mediaPath => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get context => text().nullable()();
  TextColumn get mood => text().nullable()();
  TextColumn get tags => text().nullable()();
  BoolColumn get isReleased => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get detectedTheme => text().nullable()();
  TextColumn get manualLinkIds => text().nullable()();
  IntColumn get capsuleUnlockDate => integer().nullable()();
  TextColumn get transcription => text().nullable()();
  TextColumn get syncUuid => text().nullable().unique()();
  IntColumn get modifiedAt => integer().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get mediaAssetId => text().nullable()();
  TextColumn get mediaKey => text().nullable()();
}

/// One tree per calendar year, with its maintained entry count.
@DataClassName('TreeRow')
class Trees extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get year => integer().unique()();
  IntColumn get entryCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get stateIndex => integer().withDefault(const Constant(0))();
}

/// Rituals the person confirmed.
@DataClassName('RitualRow')
class Rituals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get signature => text().withDefault(const Constant(''))();
  IntColumn get statusIndex => integer().withDefault(const Constant(0))();
  IntColumn get cadenceDays => integer().withDefault(const Constant(7))();
  IntColumn get preferredHour => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get lastObservedAt => integer().nullable()();
  IntColumn get nextDueAt => integer().nullable()();
  IntColumn get occurrenceCount => integer().withDefault(const Constant(0))();
}

/// Full-text index over the written fields of `entries` (external content:
/// the text lives once, in `entries`, and the index is kept in step by
/// triggers). Trigram tokens give substring matching in any script, ignoring
/// case and accents. Like everything else, it sits inside the encrypted file.
const List<String> entriesFtsStatements = [
  'CREATE VIRTUAL TABLE entries_fts USING fts5('
      'text, title, context, mood, transcription, '
      "content='entries', content_rowid='id', "
      "tokenize='trigram remove_diacritics 1')",
  'CREATE TRIGGER entries_fts_insert AFTER INSERT ON entries BEGIN '
      'INSERT INTO entries_fts(rowid, text, title, context, mood, '
      'transcription) VALUES (new.id, new.text, new.title, new.context, '
      'new.mood, new.transcription); END',
  'CREATE TRIGGER entries_fts_delete AFTER DELETE ON entries BEGIN '
      'INSERT INTO entries_fts(entries_fts, rowid, text, title, context, '
      "mood, transcription) VALUES ('delete', old.id, old.text, old.title, "
      'old.context, old.mood, old.transcription); END',
  'CREATE TRIGGER entries_fts_update AFTER UPDATE OF text, title, context, '
      'mood, transcription ON entries BEGIN '
      'INSERT INTO entries_fts(entries_fts, rowid, text, title, context, '
      "mood, transcription) VALUES ('delete', old.id, old.text, old.title, "
      'old.context, old.mood, old.transcription); '
      'INSERT INTO entries_fts(rowid, text, title, context, mood, '
      'transcription) VALUES (new.id, new.text, new.title, new.context, '
      'new.mood, new.transcription); END',
];

/// The drift view of the schema: table definitions, creation and (from
/// version 2 on) migrations, plus change notifications for watchers.
///
/// Queries and writes go through `SeedlingDatabase`, which shares this
/// connection.
@DriftDatabase(tables: [Entries, Trees, Rituals])
class SeedlingSchema extends _$SeedlingSchema {
  SeedlingSchema(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final statement in entriesFtsStatements) {
        await customStatement(statement);
      }
    },
  );
}
