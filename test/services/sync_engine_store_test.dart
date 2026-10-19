// SyncEngine against a real ObjectBox store and an in-memory backend.
// Needs the native ObjectBox library; skipped otherwise.
import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/core/services/sync/drive_sync_log.dart';
import 'package:seedling/core/services/sync/google_drive_sync_service.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_metadata.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession extends Fake implements SyncEncryptionSession {}

/// Pass-through "encryption" that still enforces the version envelope.
class _FakeCrypto extends Fake implements SyncCryptoService {
  @override
  Future<SyncEncryptionSession> createEncryptionSession() async =>
      _FakeSession();

  @override
  Future<Map<String, dynamic>> encryptRecordFields(
    Map<String, dynamic> record, {
    SyncEncryptionSession? session,
  }) async => {
    ...record,
    'syncEncryptionVersion': SyncCryptoService.syncEncryptionVersion,
  };

  @override
  Future<Map<String, dynamic>> decryptRecordFields(
    Map<String, dynamic> record,
  ) async {
    if (record['syncEncryptionVersion'] == null) {
      throw const SyncUnversionedRecordException();
    }
    return Map<String, dynamic>.from(record);
  }
}

class _MemoryBackend implements SyncBackend {
  final saved = <Map<String, dynamic>>[];
  final deleted = <String>[];
  var fetchCalls = 0;
  SyncFetchResult? nextFetch;

  /// When set, saveRecords waits for it (simulates a slow network).
  Completer<void>? gate;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> getAccountStatus() async => 'test';
  @override
  Future<void> saveRecord(Map<String, dynamic> record) => saveRecords([record]);
  @override
  Future<void> deleteRecord(String syncUUID) => deleteRecords([syncUUID]);
  @override
  Future<void> saveRecords(List<Map<String, dynamic>> records) async {
    await gate?.future;
    saved.addAll(records);
  }

  @override
  Future<void> deleteRecords(List<String> syncUUIDs) async {
    deleted.addAll(syncUUIDs);
  }

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async {
    fetchCalls++;
    final result = nextFetch;
    nextFetch = null;
    return result ??
        const SyncFetchResult(
          records: [],
          deletedUUIDs: [],
          newChangeToken: null,
        );
  }

  @override
  Future<String?> uploadAsset(String localPath, String syncUUID) async => null;
  @override
  Future<String?> downloadAsset(String syncUUID, String targetPath) async =>
      null;
  @override
  Future<bool> connect() async => true;
  @override
  Future<void> disconnect() async {}
}

class _MemoryDrive implements DriveFileStore {
  final _files = <String, ({String name, List<int> bytes})>{};
  var _nextId = 0;

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    await Future<void>.delayed(Duration.zero);
    return [
      for (final MapEntry(:key, :value) in _files.entries)
        if (value.name.startsWith(prefix))
          DriveFileInfo(id: key, name: value.name),
    ];
  }

  @override
  Future<List<int>?> read(String fileId) async => _files[fileId]?.bytes;

  @override
  Future<String> create(String name, List<int> bytes) async {
    await Future<void>.delayed(Duration.zero);
    final id = 'f${_nextId++}';
    _files[id] = (name: name, bytes: bytes);
    return id;
  }

  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {
    await Future<void>.delayed(Duration.zero);
    _files[fileId] = (name: _files[fileId]!.name, bytes: bytes);
  }
}

Map<String, dynamic> _record(
  String uuid, {
  required DateTime modifiedAt,
  String? text,
  bool isDeleted = false,
  String? mediaPath,
  int typeIndex = 0,
  bool versioned = true,
}) => {
  'syncUUID': uuid,
  'typeIndex': typeIndex,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
  'modifiedAt': modifiedAt.millisecondsSinceEpoch,
  'text': text,
  'isDeleted': isDeleted,
  'deletedAt': isDeleted ? modifiedAt.millisecondsSinceEpoch : null,
  'mediaPath': mediaPath,
  if (versioned) 'syncEncryptionVersion': 2,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  ObjectBoxDatabase? db;
  late SyncMetadata metadata;
  late _MemoryBackend backend;
  late SyncEngine engine;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'sync_enabled_test': true});
    metadata = SyncMetadata(
      await SharedPreferences.getInstance(),
      namespace: 'test',
    );
    // Pretend this device already did its full upload, so tests only see
    // the changes they create.
    await metadata.setFormatVersion(SyncEngine.currentFormatVersion);
    dir = await Directory.systemTemp.createTemp('sync_store');
    try {
      db = await ObjectBoxDatabase.openForTesting(
        directory: dir.path,
        encryptionService: AtRestEncryptionService(),
      );
    } on ArgumentError catch (e) {
      if (!'$e'.contains('dynamic library')) rethrow;
      db = null;
    }
    backend = _MemoryBackend();
    if (db != null) {
      engine = SyncEngine(
        database: db!,
        backend: backend,
        metadata: metadata,
        cryptoService: _FakeCrypto(),
        mediaBasePath: '/data/app/media',
      );
    }
  });

  tearDown(() async {
    if (db != null) engine.dispose();
    db?.close();
    await dir.delete(recursive: true);
  });

  bool skip() {
    if (db != null) return false;
    markTestSkipped('ObjectBox native library not available');
    return true;
  }

  test('an edit queued while a push is in flight is not dropped', () async {
    if (skip()) return;
    final entry = await db!.saveEntry(Entry.line(text: 'v1'));
    engine.queuePush(entry, SyncChangeType.create);

    backend.gate = Completer<void>();
    final pushing = engine.push();
    await Future<void>.delayed(Duration.zero);

    // The user edits again while the first push is on the network.
    final edited = db!.getEntry(entry.id)!..text = 'v2';
    db!.updateEntry(edited);
    engine.queuePush(edited, SyncChangeType.update);

    // A pull requested now must wait for the push to finish.
    final pulling = engine.pull();
    await Future<void>.delayed(Duration.zero);
    expect(backend.fetchCalls, 0);

    backend.gate!.complete();
    await pushing;
    await pulling;
    expect(backend.fetchCalls, 1);

    // The second edit is still queued...
    expect(metadata.pendingChanges.map((c) => c.syncUUID), [entry.syncUUID]);
    // ...and goes out on the next push.
    backend.gate = null;
    await engine.push();
    expect(backend.saved.last['text'], 'v2');
    expect(metadata.pendingChanges, isEmpty);
  });

  test('merging remote deletes and restores keeps tree counts right', () async {
    if (skip()) return;
    final local = await db!.saveEntry(Entry.line(text: 'here'));
    final base = db!.currentTree!.entryCount;
    final t = DateTime.now().add(const Duration(minutes: 1));

    // A new remote record that is already in the trash: no growth.
    backend.nextFetch = SyncFetchResult(
      records: [
        _record(
          '11111111-2222-4333-8444-555555555555',
          modifiedAt: t,
          text: 'trashed elsewhere',
          isDeleted: true,
        ),
      ],
      deletedUUIDs: const [],
    );
    await engine.pull();
    expect(db!.currentTree!.entryCount, base);
    expect(
      db!.getDeletedEntries().map((e) => e.text),
      contains('trashed elsewhere'),
    );

    // The local entry was deleted on another device.
    backend.nextFetch = SyncFetchResult(
      records: [_record(local.syncUUID!, modifiedAt: t, isDeleted: true)],
      deletedUUIDs: const [],
    );
    await engine.pull();
    expect(db!.currentTree!.entryCount, base - 1);
    // Remote modifiedAt is kept, not replaced by "now".
    expect(
      db!.getEntry(local.id)!.modifiedAt!.millisecondsSinceEpoch,
      t.millisecondsSinceEpoch,
    );

    // ...and restored there again.
    backend.nextFetch = SyncFetchResult(
      records: [
        _record(
          local.syncUUID!,
          modifiedAt: t.add(const Duration(minutes: 1)),
          text: 'here',
        ),
      ],
      deletedUUIDs: const [],
    );
    await engine.pull();
    expect(db!.currentTree!.entryCount, base);
  });

  test('purged trash is deleted remotely too', () async {
    if (skip()) return;
    final old = await db!.saveEntries([
      Entry.line(text: 'long gone')
        ..isDeleted = true
        ..deletedAt = DateTime.now().toUtc().subtract(const Duration(days: 40)),
    ]);
    expect(await db!.purgeExpiredEntries(), 1);

    await engine.init();
    expect(backend.deleted, [old.single.syncUUID]);
    expect(metadata.pendingChanges, isEmpty);
  });

  test('unversioned remote records are ignored', () async {
    if (skip()) return;
    backend.nextFetch = SyncFetchResult(
      records: [
        _record(
          '22222222-3333-4444-8555-666666666666',
          modifiedAt: DateTime.now(),
          text: 'injected',
          versioned: false,
        ),
      ],
      deletedUUIDs: const [],
      newChangeToken: 't1',
    );
    final result = await engine.pull();
    expect(result.success, isTrue);
    expect(db!.getAllEntries(), isEmpty);
    // The token still advances, so one bad record can't wedge sync.
    expect(metadata.changeToken, 't1');
  });

  test('remote media paths are confined to the media folder', () async {
    if (skip()) return;
    backend.nextFetch = SyncFetchResult(
      records: [
        _record(
          '33333333-4444-4555-8666-777777777777',
          modifiedAt: DateTime.now(),
          typeIndex: EntryType.photo.index,
          mediaPath: '/var/mobile/../../etc/passwd',
        ),
        _record(
          '44444444-5555-4666-8777-888888888888',
          modifiedAt: DateTime.now(),
          typeIndex: EntryType.voice.index,
          mediaPath: '../../voices/../secret.m4a',
        ),
      ],
      deletedUUIDs: const [],
    );
    await engine.pull();
    final paths = db!.getAllEntries().map((e) => e.mediaPath).toSet();
    expect(paths, {
      '/data/app/media/photos/passwd',
      '/data/app/media/voices/secret.m4a',
    });
  });

  test('pushed media paths never carry absolute device paths', () async {
    if (skip()) return;
    final entry = await db!.saveEntry(
      Entry.photo(mediaPath: '/somewhere/else/IMG_1.jpg'),
    );
    engine.queuePush(entry, SyncChangeType.create);
    await engine.push();
    expect(backend.saved.single['mediaPath'], 'photos/IMG_1.jpg');
  });

  test('two devices converge through Google Drive logs', () async {
    if (skip()) return;
    final drive = _MemoryDrive();
    final dirB = await Directory.systemTemp.createTemp('sync_store_b');
    final dbB = await ObjectBoxDatabase.openForTesting(
      directory: dirB.path,
      encryptionService: AtRestEncryptionService(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled_b', true);
    final metaB = SyncMetadata(prefs, namespace: 'b');
    await metaB.setFormatVersion(SyncEngine.currentFormatVersion);
    final engineA = SyncEngine(
      database: db!,
      backend: GoogleDriveSyncService.withStore(
        drive,
        deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
      metadata: metadata,
      cryptoService: _FakeCrypto(),
    );
    final engineB = SyncEngine(
      database: dbB,
      backend: GoogleDriveSyncService.withStore(
        drive,
        deviceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ),
      metadata: metaB,
      cryptoService: _FakeCrypto(),
    );
    try {
      final fromA = await db!.saveEntry(Entry.line(text: 'from A'));
      final fromB = await dbB.saveEntry(Entry.line(text: 'from B'));
      engineA.queuePush(fromA, SyncChangeType.create);
      engineB.queuePush(fromB, SyncChangeType.create);
      // Both push at the same time.
      await Future.wait([engineA.push(), engineB.push()]);
      await Future.wait([engineA.pull(), engineB.pull()]);

      expect(db!.getAllEntries().map((e) => e.text).toSet(), {
        'from A',
        'from B',
      });
      expect(dbB.getAllEntries().map((e) => e.text).toSet(), {
        'from A',
        'from B',
      });
      expect(dbB.currentTree!.entryCount, 2);
    } finally {
      engineA.dispose();
      engineB.dispose();
      dbB.close();
      await dirB.delete(recursive: true);
    }
  });

  test('first enable uploads existing entries', () async {
    if (skip()) return;
    await metadata.setEnabled(false);
    final a = await db!.saveEntry(Entry.line(text: 'before sync'));
    await engine.setEnabled(true);
    expect(backend.saved.map((r) => r['syncUUID']), [a.syncUUID]);
  });
}
