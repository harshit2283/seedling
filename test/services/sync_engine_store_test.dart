// SyncEngine against a real ObjectBox store and an in-memory backend.
// Needs the native ObjectBox library; skipped otherwise.
import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/core/services/sync/google_drive_sync_service.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_metadata.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/core/services/sync/sync_quarantine.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/memory_file_store.dart';

class _FakeSession extends Fake implements SyncEncryptionSession {}

/// Pass-through "encryption" that still enforces the version envelope.
class _FakeCrypto extends Fake implements SyncCryptoService {
  bool keyMatchesKeyring = true;

  @override
  Future<bool> hasPassphrase() async => true;

  @override
  Future<bool> matchesKeyring(Map<String, dynamic> keyring) async =>
      keyMatchesKeyring;

  Map<String, dynamic>? ownKeyring = {
    'kdfSalt': 'c2FsdHNhbHRzYWx0c2FsdA==',
    'check': 'ok',
  };
  @override
  Future<Map<String, dynamic>?> keyringForCurrentKey() async => ownKeyring;

  String fingerprint = 'key-1';
  @override
  Future<String?> keyFingerprint() async => fingerprint;

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

  /// Records whose text is in here fail to decrypt (wrong key, forged).
  final undecryptable = <String>{};

  @override
  Future<Map<String, dynamic>> decryptRecordFields(
    Map<String, dynamic> record,
  ) async {
    if (record['syncEncryptionVersion'] == null) {
      throw const SyncUnversionedRecordException();
    }
    if (undecryptable.contains(record['text'])) {
      throw const SyncPayloadCryptoException('Failed to decrypt');
    }
    return Map<String, dynamic>.from(record);
  }
}

class _MemoryBackend extends SyncBackend {
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

  /// When set, fetchChanges throws it (once).
  Object? fetchError;

  /// When set, every call waits on it (a hung backend).
  Completer<void>? hang;

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async {
    await hang?.future;
    fetchCalls++;
    if (returnNullFetch) return null;
    final error = fetchError;
    if (error != null) {
      fetchError = null;
      throw error;
    }
    final result = nextFetch;
    nextFetch = null;
    return result ??
        const SyncFetchResult(
          records: [],
          deletedUUIDs: [],
          newChangeToken: null,
        );
  }

  Map<String, dynamic>? keyring;
  Object? keyringError;
  @override
  Future<Map<String, dynamic>?> readKeyring() async {
    if (keyringError != null) throw keyringError!;
    return keyring;
  }

  @override
  Future<Map<String, dynamic>> publishKeyring(Map<String, dynamic> k) async {
    // Same rules as DriveSyncLogStore.publishKeyring.
    final existing = keyring;
    if (existing == null ||
        (existing['check'] == null && existing['kdfSalt'] == k['kdfSalt'])) {
      keyring = k;
    }
    return keyring!;
  }

  final blobs = <String, List<int>>{};
  final blobDeletes = <String>[];
  var blobUploads = 0;
  final uploadCalls = <({String assetId, bool replace})>[];
  Object? uploadError;
  final orphanCalls = <Set<String>>[];
  List<String> idle = const [];
  final deletedDeviceLogs = <String>[];
  var returnNullFetch = false;

  @override
  Future<int> deleteOrphanMediaBlobs(Set<String> referenced) async {
    orphanCalls.add(referenced);
    return 0;
  }

  @override
  Future<List<String>> idleDeviceIds(Duration idle) async => this.idle;

  @override
  Future<void> deleteDeviceLogs(List<String> deviceIds) async {
    deletedDeviceLogs.addAll(deviceIds);
  }

  @override
  Future<void> uploadMediaBlob(
    String assetId,
    File ciphertext, {
    bool replace = false,
  }) async {
    uploadCalls.add((assetId: assetId, replace: replace));
    final error = uploadError;
    if (error != null) {
      uploadError = null;
      throw error;
    }
    blobUploads++;
    blobs[assetId] = await ciphertext.readAsBytes();
  }

  @override
  Future<bool> downloadMediaBlob(String assetId, File target) async {
    final bytes = blobs[assetId];
    if (bytes == null) return false;
    await target.writeAsBytes(bytes);
    return true;
  }

  @override
  Future<void> deleteMediaBlob(String assetId) async {
    blobDeletes.add(assetId);
    blobs.remove(assetId);
  }

  @override
  Future<bool> connect() async => true;
  @override
  Future<void> disconnect() async {}
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
    final drive = MemoryFileStore();
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

  test('a key derived with another salt never pushes', () async {
    if (skip()) return;
    backend.keyring = {'kdfSalt': 'AAAAAAAAAAAAAAAAAAAAAA=='};
    final crypto = _FakeCrypto()..keyMatchesKeyring = false;
    final mismatched = SyncEngine(
      database: db!,
      backend: backend,
      metadata: metadata,
      cryptoService: crypto,
    );
    final entry = await db!.saveEntry(Entry.line(text: 'unreadable'));
    await metadata.addPendingChange(
      SyncChange(
        syncUUID: entry.syncUUID!,
        changeType: SyncChangeType.create,
        timestamp: DateTime.now(),
      ),
    );
    await mismatched.init();
    expect(mismatched.currentState, SyncState.error);
    expect(metadata.lastError, contains('Re-enter your sync passphrase'));
    expect(backend.saved, isEmpty);
    mismatched.dispose();
  });

  group('encrypted media', () {
    late Directory mediaA;
    late Directory mediaB;
    late Directory dirB;
    late ObjectBoxDatabase dbB;
    late SyncMetadata metaB;
    var allowed = true;

    setUp(() async {
      if (db == null) return;
      allowed = true;
      mediaA = await Directory.systemTemp.createTemp('media_a');
      mediaB = await Directory.systemTemp.createTemp('media_b');
      dirB = await Directory.systemTemp.createTemp('sync_store_b');
      dbB = await ObjectBoxDatabase.openForTesting(
        directory: dirB.path,
        encryptionService: AtRestEncryptionService(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sync_enabled_b', true);
      metaB = SyncMetadata(prefs, namespace: 'b');
      await metaB.setFormatVersion(SyncEngine.currentFormatVersion);
    });

    tearDown(() async {
      if (db == null) return;
      dbB.close();
      for (final d in [mediaA, mediaB, dirB]) {
        await d.delete(recursive: true);
      }
    });

    SyncEngine engineFor(
      ObjectBoxDatabase database,
      SyncMetadata meta,
      Directory media,
    ) => SyncEngine(
      database: database,
      backend: backend,
      metadata: meta,
      cryptoService: _FakeCrypto(),
      mediaBasePath: media.path,
      networkAllowed: () => allowed,
    );

    Future<Entry> photoOn(ObjectBoxDatabase database, Directory media) async {
      final file = File('${media.path}/photos/IMG_1.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.generate(200000, (i) => i % 251));
      return database.saveEntry(Entry.photo(mediaPath: file.path, text: 'p'));
    }

    test('a new photo is uploaded encrypted and downloaded on pull', () async {
      if (skip()) return;
      final a = engineFor(db!, metadata, mediaA);
      final b = engineFor(dbB, metaB, mediaB);
      final photo = await photoOn(db!, mediaA);
      a.queuePush(photo, SyncChangeType.create);
      await a.push();

      // One blob, and it is ciphertext.
      expect(backend.blobs, hasLength(1));
      final blob = backend.blobs.values.single;
      final original = File(photo.mediaPath!).readAsBytesSync();
      expect(blob, isNot(original));
      expect(blob.length, greaterThan(original.length));
      final record = backend.saved.single;
      expect(record['mediaAssetId'], backend.blobs.keys.single);
      expect(record['mediaKey'], isA<String>());
      expect(db!.getEntry(photo.id)!.mediaAssetId, record['mediaAssetId']);

      // Device B: record arrives first (placeholder), file follows.
      backend.nextFetch = SyncFetchResult(
        records: backend.saved,
        deletedUUIDs: const [],
      );
      await b.pull();
      await b.downloadPendingMedia();
      final pulled = dbB.getAllEntries().single;
      expect(pulled.mediaPath, startsWith('${mediaB.path}/photos/'));
      expect(File(pulled.mediaPath!).readAsBytesSync(), original);
      expect(dbB.getEntriesNeedingMediaDownload(), isEmpty);

      // Pushing again doesn't re-upload.
      a.queuePush(db!.getEntry(photo.id)!, SyncChangeType.update);
      await a.push();
      expect(backend.blobUploads, 1);
      a.dispose();
      b.dispose();
    });

    test('a missing blob stays pending and resumes later', () async {
      if (skip()) return;
      final a = engineFor(db!, metadata, mediaA);
      final b = engineFor(dbB, metaB, mediaB);
      final photo = await photoOn(db!, mediaA);
      a.queuePush(photo, SyncChangeType.create);
      await a.push();
      final saved = List<Map<String, dynamic>>.of(backend.saved);
      final blobs = Map<String, List<int>>.of(backend.blobs);
      backend.blobs.clear(); // e.g. not propagated yet

      backend.nextFetch = SyncFetchResult(
        records: saved,
        deletedUUIDs: const [],
      );
      await b.pull();
      await b.downloadPendingMedia();
      expect(dbB.getEntriesNeedingMediaDownload(), hasLength(1));

      backend.blobs.addAll(blobs);
      await b.downloadPendingMedia();
      expect(dbB.getEntriesNeedingMediaDownload(), isEmpty);
      a.dispose();
      b.dispose();
    });

    test('a tampered blob is rejected and nothing is stored', () async {
      if (skip()) return;
      final a = engineFor(db!, metadata, mediaA);
      final b = engineFor(dbB, metaB, mediaB);
      final photo = await photoOn(db!, mediaA);
      a.queuePush(photo, SyncChangeType.create);
      await a.push();
      final id = backend.blobs.keys.single;
      backend.blobs[id]![100] ^= 0xff;

      backend.nextFetch = SyncFetchResult(
        records: backend.saved,
        deletedUUIDs: const [],
      );
      await b.pull();
      await b.downloadPendingMedia();
      expect(dbB.getAllEntries().single.mediaPath, isNull);
      expect(
        Directory('${mediaB.path}/photos').existsSync() &&
            Directory('${mediaB.path}/photos').listSync().isNotEmpty,
        isFalse,
      );
      a.dispose();
      b.dispose();
    });

    test('deleting a memory removes its blob (also via purge)', () async {
      if (skip()) return;
      final a = engineFor(db!, metadata, mediaA);
      final photo = await photoOn(db!, mediaA);
      a.queuePush(photo, SyncChangeType.create);
      await a.push();
      final id = backend.blobs.keys.single;

      final stored = db!.getEntry(photo.id)!;
      await db!.deleteEntry(stored.id);
      a.queuePush(stored, SyncChangeType.delete);
      await a.push();
      expect(backend.blobDeletes, [id]);
      expect(backend.blobs, isEmpty);

      // Purged trash takes its blob with it too.
      final second = await photoOn(db!, mediaA);
      a.queuePush(second, SyncChangeType.create);
      await a.push();
      final secondId = backend.blobs.keys.single;
      await db!.saveEntry(
        db!.getEntry(second.id)!
          ..isDeleted = true
          ..deletedAt = DateTime.now().toUtc().subtract(
            const Duration(days: 40),
          ),
      );
      await db!.purgeExpiredEntries();
      await a.init();
      expect(backend.blobDeletes, [id, secondId]);
      a.dispose();
    });

    test('no media (or records) move before the cloud-sync opt-in', () async {
      if (skip()) return;
      allowed = false;
      final a = engineFor(db!, metadata, mediaA);
      final photo = await photoOn(db!, mediaA);
      a.queuePush(photo, SyncChangeType.create);
      await a.push();
      await a.init();
      await a.downloadPendingMedia();
      expect(backend.blobUploads, 0);
      expect(backend.saved, isEmpty);
      expect(backend.fetchCalls, 0);
      a.dispose();
    });

    test('files over 50 MB are skipped with a warning', () async {
      if (skip()) return;
      final a = engineFor(db!, metadata, mediaA);
      final big = File('${mediaA.path}/voices/long.m4a')
        ..createSync(recursive: true);
      final raf = big.openSync(mode: FileMode.write)
        ..truncateSync(51 * 1024 * 1024)
        ..closeSync();
      expect(raf, isNotNull);
      final entry = await db!.saveEntry(Entry.voice(mediaPath: big.path));
      a.queuePush(entry, SyncChangeType.create);
      final result = await a.push();
      expect(result.success, isTrue);
      expect(backend.blobUploads, 0);
      expect(backend.saved.single['mediaAssetId'], isNull);
      expect(metadata.lastError, contains('50 MB'));
      a.dispose();
    });
  });

  test('undecryptable records are quarantined; the rest still merge', () async {
    if (skip()) return;
    final crypto = _FakeCrypto()..undecryptable.add('forged');
    final e = SyncEngine(
      database: db!,
      backend: backend,
      metadata: metadata,
      cryptoService: crypto,
    );
    backend.nextFetch = SyncFetchResult(
      records: [
        _record(
          '55555555-6666-4777-8888-999999999999',
          modifiedAt: DateTime.now(),
          text: 'forged',
        ),
        _record(
          '66666666-7777-4888-8999-aaaaaaaaaaaa',
          modifiedAt: DateTime.now(),
          text: 'fine',
        ),
      ],
      deletedUUIDs: const [],
      newChangeToken: 't2',
    );
    final result = await e.pull();
    expect(result.success, isTrue);
    expect(result.quarantinedCount, 1);
    expect(db!.getAllEntries().map((x) => x.text), ['fine']);
    // The token moves on: one bad record can't wedge sync forever.
    expect(metadata.changeToken, 't2');
    expect(e.quarantineCount, 1);
    expect(metadata.lastError, contains("couldn't be decrypted"));

    // Once the key is fixed, the quarantined record is retried and merged.
    crypto.undecryptable.clear();
    backend.nextFetch = const SyncFetchResult(records: [], deletedUUIDs: []);
    await e.pull();
    expect(db!.getAllEntries().map((x) => x.text).toSet(), {'fine', 'forged'});
    expect(e.quarantineCount, 0);
    e.dispose();
  });

  test('a failed pull blocks pushing until a pull succeeds', () async {
    if (skip()) return;
    final entry = await db!.saveEntry(Entry.line(text: 'local edit'));
    engine.queuePush(entry, SyncChangeType.create);
    backend.fetchError = const SyncPassphraseMissingException();
    await engine.init();
    expect(backend.saved, isEmpty);
    expect((await engine.push()).success, isFalse);
    expect(backend.saved, isEmpty);

    await engine.pull();
    expect((await engine.push()).success, isTrue);
    expect(backend.saved, hasLength(1));
  });

  test('init never throws: keyring errors end up in lastError', () async {
    if (skip()) return;
    backend.keyringError = StateError('Google Drive not connected');
    await engine.init();
    expect(engine.currentState, SyncState.error);
    expect(metadata.lastError, contains('not connected'));
  });

  test('a hung backend call times out instead of stalling the queue', () async {
    if (skip()) return;
    final e = SyncEngine(
      database: db!,
      backend: backend,
      metadata: metadata,
      cryptoService: _FakeCrypto(),
      callTimeout: const Duration(milliseconds: 50),
    );
    backend.hang = Completer<void>();
    final result = await e.pull();
    expect(result.success, isFalse);
    expect(metadata.lastError, contains('timed out'));
    backend.hang!.complete();
    backend.hang = null;
    expect((await e.pull()).success, isTrue);
    e.dispose();
  });

  test('a new key re-uploads everything under it', () async {
    if (skip()) return;
    final crypto = _FakeCrypto();
    final e = SyncEngine(
      database: db!,
      backend: backend,
      metadata: metadata,
      cryptoService: crypto,
    );
    final a = await db!.saveEntry(Entry.line(text: 'a'));
    await e.init();
    expect(backend.saved, isEmpty);

    // E.g. lost a keyring race and re-entered the passphrase.
    crypto.fingerprint = 'key-2';
    await e.init();
    expect(backend.saved.map((r) => r['syncUUID']), [a.syncUUID]);
    e.dispose();
  });

  group('review round 3', () {
    SyncEngine engineWith(_FakeCrypto crypto, {SyncQuarantine? quarantine}) =>
        SyncEngine(
          database: db!,
          backend: backend,
          metadata: metadata,
          cryptoService: crypto,
          quarantine: quarantine,
        );

    test(
      'a re-uploaded copy replaces a quarantined one (same modifiedAt)',
      () async {
        if (skip()) return;
        final crypto = _FakeCrypto()..undecryptable.add('under the old key');
        final e = engineWith(crypto);
        const uuid = '77777777-8888-4999-8aaa-bbbbbbbbbbbb';
        final t = DateTime(2026, 5, 1);
        backend.nextFetch = SyncFetchResult(
          records: [_record(uuid, modifiedAt: t, text: 'under the old key')],
          deletedUUIDs: const [],
          newChangeToken: 't1',
        );
        await e.pull();
        expect(e.quarantineCount, 1);

        // The writer re-keyed and re-uploaded the same version (modifiedAt
        // unchanged). Before: the tie kept the bad copy and dropped this one.
        backend.nextFetch = SyncFetchResult(
          records: [_record(uuid, modifiedAt: t, text: 'readable again')],
          deletedUUIDs: const [],
          newChangeToken: 't2',
        );
        await e.pull();
        expect(db!.getAllEntries().map((x) => x.text), ['readable again']);
        expect(e.quarantineCount, 0);
        expect(metadata.changeToken, 't2');
        e.dispose();
      },
    );

    test('a forged far-future copy cannot hide the genuine one', () async {
      if (skip()) return;
      final crypto = _FakeCrypto()..undecryptable.add('forged');
      final e = engineWith(crypto);
      const uuid = '88888888-9999-4aaa-8bbb-cccccccccccc';
      backend.nextFetch = SyncFetchResult(
        records: [
          _record(uuid, modifiedAt: DateTime(2099), text: 'forged'),
          _record(uuid, modifiedAt: DateTime(2026, 5, 1), text: 'genuine'),
        ],
        deletedUUIDs: const [],
      );
      await e.pull();
      expect(db!.getAllEntries().map((x) => x.text), ['genuine']);
      e.dispose();
    });

    test('no push without a verifiable keyring', () async {
      if (skip()) return;
      // A fixed-salt key can't recreate a missing keyring: block.
      final crypto = _FakeCrypto()..ownKeyring = null;
      final e = engineWith(crypto);
      final entry = await db!.saveEntry(Entry.line(text: 'x'));
      e.queuePush(entry, SyncChangeType.create);
      expect((await e.push()).success, isFalse);
      expect(backend.saved, isEmpty);
      e.dispose();
    });

    test('a keyring without a key check gets one (same salt)', () async {
      if (skip()) return;
      final crypto = _FakeCrypto();
      backend.keyring = {'kdfSalt': crypto.ownKeyring!['kdfSalt']};
      final e = engineWith(crypto);
      final entry = await db!.saveEntry(Entry.line(text: 'x'));
      e.queuePush(entry, SyncChangeType.create);
      expect((await e.push()).success, isTrue);
      expect(backend.keyring!['check'], 'ok');
      e.dispose();
    });

    test('a not-connected pull is not a successful pull', () async {
      if (skip()) return;
      backend.returnNullFetch = true;
      final result = await engine.pull();
      expect(result.success, isFalse);
      final entry = await db!.saveEntry(Entry.line(text: 'x'));
      engine.queuePush(entry, SyncChangeType.create);
      expect((await engine.push()).success, isFalse);
    });

    test('an interrupted media upload is retried under the same id', () async {
      if (skip()) return;
      final media = await Directory.systemTemp.createTemp('media_r3');
      try {
        final file = File('${media.path}/photos/p.jpg')
          ..createSync(recursive: true)
          ..writeAsBytesSync(List<int>.filled(1000, 7));
        final e = SyncEngine(
          database: db!,
          backend: backend,
          metadata: metadata,
          cryptoService: _FakeCrypto(),
          mediaBasePath: media.path,
        );
        final entry = await db!.saveEntry(Entry.photo(mediaPath: file.path));
        e.queuePush(entry, SyncChangeType.create);
        backend.uploadError = const SocketException('dropped');
        expect((await e.push()).success, isFalse);
        expect((await e.push()).success, isTrue);
        expect(backend.uploadCalls, hasLength(2));
        expect(backend.uploadCalls[1].assetId, backend.uploadCalls[0].assetId);
        expect(backend.uploadCalls[1].replace, isTrue);
        expect(backend.blobs.keys, [backend.uploadCalls[0].assetId]);
        expect(metadata.pendingMediaUploads, isEmpty);
        e.dispose();
      } finally {
        await media.delete(recursive: true);
      }
    });

    test(
      'housekeeping: orphan blobs and idle logs after a full re-upload',
      () async {
        if (skip()) return;
        final e = engineWith(_FakeCrypto());
        final a = await db!.saveEntry(
          Entry.line(text: 'a')
            ..mediaAssetId = '99999999-aaaa-4bbb-8ccc-dddddddddddd',
        );
        backend.idle = ['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'];
        await e.pull();
        // Let the background housekeeping finish.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(backend.orphanCalls.single, contains(a.mediaAssetId));
        expect(backend.saved.map((r) => r['syncUUID']), contains(a.syncUUID));
        expect(backend.deletedDeviceLogs, [
          'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        ]);
        // At most daily.
        await e.pull();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(backend.orphanCalls, hasLength(1));
        e.dispose();
      },
    );

    test(
      'quarantine lives in a file, migrates from prefs, writes on change',
      () async {
        if (skip()) return;
        final stateDir = await Directory.systemTemp.createTemp('quarantine');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'sync_quarantine_test',
            '[{"syncUUID":"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee","x":1}]',
          );
          final q = SyncQuarantine(
            directory: () async => stateDir,
            namespace: 'test',
            legacyMetadata: metadata,
          );
          expect(await q.records(), hasLength(1));
          expect(prefs.getString('sync_quarantine_test'), isNull);
          final file = File('${stateDir.path}/sync_state/quarantine_test.json');
          expect(file.existsSync(), isTrue);
          final stamp = file.lastModifiedSync();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await q.replace(await q.records()); // unchanged: no rewrite
          expect(file.lastModifiedSync(), stamp);
          // Survives a restart.
          final reopened = SyncQuarantine(
            directory: () async => stateDir,
            namespace: 'test',
          );
          expect(await reopened.records(), hasLength(1));
        } finally {
          await stateDir.delete(recursive: true);
        }
      },
    );
  });

  test('first enable uploads existing entries', () async {
    if (skip()) return;
    await metadata.setEnabled(false);
    final a = await db!.saveEntry(Entry.line(text: 'before sync'));
    await engine.setEnabled(true);
    expect(backend.saved.map((r) => r['syncUUID']), [a.syncUUID]);
  });
}
