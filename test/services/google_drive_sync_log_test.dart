import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/drive_sync_log.dart';
import 'package:seedling/core/services/sync/google_drive_sync_service.dart';

import '../support/memory_file_store.dart';

/// In-memory appData folder. Every call yields to the event loop first, so
/// concurrent pushes from several "devices" genuinely interleave.
const _devA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _devB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _devC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

Map<String, dynamic> _rec(
  String uuid, {
  required int modifiedAt,
  String? text,
}) => {
  'syncUUID': uuid,
  'modifiedAt': modifiedAt,
  'text': text,
  'syncEncryptionVersion': 2,
};

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  late MemoryFileStore drive;
  late GoogleDriveSyncService a;
  late GoogleDriveSyncService b;
  late GoogleDriveSyncService c;

  setUp(() {
    drive = MemoryFileStore();
    a = GoogleDriveSyncService.withStore(drive, deviceId: _devA);
    b = GoogleDriveSyncService.withStore(drive, deviceId: _devB);
    c = GoogleDriveSyncService.withStore(drive, deviceId: _devC);
  });

  test('concurrent pushes from two devices both arrive', () async {
    await Future.wait([
      for (var i = 0; i < 5; i++) ...[
        a.saveRecord(_rec(_uuid(i), modifiedAt: 1000 + i, text: 'a$i')),
        b.saveRecord(_rec(_uuid(100 + i), modifiedAt: 1000 + i, text: 'b$i')),
      ],
    ]);

    final fetched = await c.fetchChanges();
    expect(fetched!.records.map((r) => r['text']).toSet(), {
      for (var i = 0; i < 5; i++) ...['a$i', 'b$i'],
    });
  });

  test('offline edits with old timestamps are not skipped', () async {
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    await a.saveRecord(_rec(_uuid(1), modifiedAt: now, text: 'fresh'));
    final first = await c.fetchChanges();
    expect(first!.records, hasLength(1));

    // B was offline (or its clock is behind): its edit is stamped a day
    // *before* what C has already seen, but it was pushed afterwards.
    final yesterday = now - const Duration(days: 1).inMilliseconds;
    await b.saveRecord(_rec(_uuid(2), modifiedAt: yesterday, text: 'late'));

    final second = await c.fetchChanges(changeToken: first.newChangeToken);
    expect(second!.records.map((r) => r['text']), ['late']);

    // Nothing new: nothing delivered again.
    final third = await c.fetchChanges(changeToken: second.newChangeToken);
    expect(third!.records, isEmpty);
    expect(third.deletedUUIDs, isEmpty);
  });

  test('deletes are delivered by sequence too', () async {
    await a.saveRecord(_rec(_uuid(1), modifiedAt: 5, text: 'x'));
    final first = await c.fetchChanges();
    await b.deleteRecord(_uuid(1));
    final second = await c.fetchChanges(changeToken: first!.newChangeToken);
    expect(second!.deletedUUIDs, [_uuid(1)]);
    expect(second.records, isEmpty);
  });

  test('a device continues its own sequence after restart', () async {
    await a.saveRecords([
      _rec(_uuid(1), modifiedAt: 1),
      _rec(_uuid(2), modifiedAt: 2),
    ]);
    final first = await c.fetchChanges();
    // Fresh instance, same device id (app restart).
    final aAgain = GoogleDriveSyncService.withStore(drive, deviceId: _devA);
    await aAgain.saveRecord(_rec(_uuid(3), modifiedAt: 3, text: 'after'));
    final second = await c.fetchChanges(changeToken: first!.newChangeToken);
    expect(second!.records.map((r) => r['text']), ['after']);
  });

  test('a batch push is a single small chunk write', () async {
    await a.saveRecords([
      for (var i = 0; i < 50; i++) _rec(_uuid(i), modifiedAt: i),
    ]);
    expect(drive.files, hasLength(1));
    expect(drive.files.values.single.name, endsWith('_c1-50.json'));
    final log = jsonDecode(utf8.decode(drive.files.values.single.bytes));
    expect((log['records'] as Map).length, 50);
  });

  test('an unreadable token falls back to a full fetch', () async {
    await a.saveRecord(_rec(_uuid(1), modifiedAt: 10, text: 'kept'));
    final fetched = await c.fetchChanges(changeToken: '99999999999999');
    expect(fetched!.records.map((r) => r['text']), ['kept']);
  });

  test('media blobs upload once, download, and delete', () async {
    final tmp = await Directory.systemTemp.createTemp('drive_blob');
    try {
      final sealed = File('${tmp.path}/x.enc')..writeAsBytesSync([9, 8, 7]);
      final id = _uuid(42);
      await a.uploadMediaBlob(id, sealed);
      await a.uploadMediaBlob(id, sealed); // retry after an interruption
      expect(
        drive.files.values.where(
          (f) => f.name.startsWith(DriveSyncLogStore.mediaPrefix),
        ),
        hasLength(1),
      );

      final out = File('${tmp.path}/out.enc');
      expect(await c.downloadMediaBlob(id, out), isTrue);
      expect(out.readAsBytesSync(), [9, 8, 7]);

      await b.deleteMediaBlob(id);
      expect(await c.downloadMediaBlob(id, out), isFalse);
      // Ids end up in a Drive query string: anything but a UUID is refused.
      await expectLater(
        a.uploadMediaBlob("x' or name contains '", sealed),
        throwsArgumentError,
      );
    } finally {
      await tmp.delete(recursive: true);
    }
  });

  test('keyring: first publisher wins and racing devices agree', () async {
    expect(await a.readKeyring(), isNull);
    final keyA = {
      'kdfSalt': base64Encode(List<int>.filled(32, 9)),
      'check': 'a',
    };
    final keyB = {
      'kdfSalt': base64Encode(List<int>.filled(32, 3)),
      'check': 'b',
    };
    final results = await Future.wait([
      a.publishKeyring(keyA),
      b.publishKeyring(keyB),
    ]);
    // Both devices, and any later reader, settle on one keyring before
    // anything is derived or pushed.
    expect(results[0]['kdfSalt'], results[1]['kdfSalt']);
    expect(results[0]['check'], results[1]['check']);
    expect((await c.readKeyring())!['kdfSalt'], results[0]['kdfSalt']);
    // Publishing again never replaces it.
    final again = await c.publishKeyring({
      'kdfSalt': base64Encode(List<int>.filled(32, 1)),
    });
    expect(again['kdfSalt'], results[0]['kdfSalt']);
  });

  test('an unreadable log from one device does not block the others', () async {
    await drive.create(
      '${DriveSyncLogStore.logPrefix}dddddddd-dddd-4ddd-8ddd-dddddddddddd'
      '_deadbeef_c1-1.json',
      [1, 2, 3],
    );
    await b.saveRecord(_rec(_uuid(1), modifiedAt: 1, text: 'ok'));
    final fetched = await c.fetchChanges();
    expect(fetched!.records.map((r) => r['text']), ['ok']);
  });

  test('a log that restarts (wiped or lost) is re-read, not ignored', () async {
    await a.saveRecords([
      _rec(_uuid(1), modifiedAt: 1),
      _rec(_uuid(2), modifiedAt: 2),
      _rec(_uuid(3), modifiedAt: 3),
    ]);
    final first = await c.fetchChanges();
    expect(first!.records, hasLength(3));

    // The zone/appData folder loses A's files; A (restarted) pushes again
    // from seq 1. Before epochs, C waited for seq > 3 and missed it.
    drive.files.removeWhere(
      (_, f) => f.name.startsWith('${DriveSyncLogStore.logPrefix}$_devA'),
    );
    final aAgain = GoogleDriveSyncService.withStore(drive, deviceId: _devA);
    await aAgain.saveRecord(_rec(_uuid(4), modifiedAt: 4, text: 'after wipe'));
    final second = await c.fetchChanges(changeToken: first.newChangeToken);
    expect(second!.records.map((r) => r['text']), ['after wipe']);
  });

  test('duplicate files from a retried create are read once', () async {
    await a.saveRecord(_rec(_uuid(1), modifiedAt: 1, text: 'once'));
    final original = drive.files.values.single;
    await drive.create(original.name, original.bytes); // Drive allows dupes
    final fetched = await c.fetchChanges();
    expect(fetched!.records.map((r) => r['text']), ['once']);
  });

  group('log store', () {
    DriveSyncLogStore storeFor(String device, {int maxChunks = 3}) =>
        DriveSyncLogStore(
          drive,
          deviceId: device,
          maxChunks: maxChunks,
          keyringSettle: Duration.zero,
        );

    test('compacts chunks into a base; readers see the same data', () async {
      final writer = storeFor(_devA);
      final reader = storeFor(_devC);
      await writer.append(records: [_rec(_uuid(1), modifiedAt: 1, text: 'v1')]);
      final mid = await reader.fetch(null);
      for (var i = 2; i <= 6; i++) {
        await writer.append(
          records: [_rec(_uuid(i), modifiedAt: i, text: 'v$i')],
        );
      }
      await writer.append(deletions: [_uuid(2)]);
      final aFiles = drive
          .namesWithPrefix('${DriveSyncLogStore.logPrefix}$_devA')
          .toList();
      expect(aFiles.where((n) => n.contains('_b')), hasLength(1));
      expect(aFiles.length, lessThanOrEqualTo(3));

      final fresh = await storeFor(_devB).fetch(null);
      expect(fresh.records.map((r) => r['text']).toSet(), {
        'v1',
        'v3',
        'v4',
        'v5',
        'v6',
      });
      expect(fresh.deletedUUIDs, [_uuid(2)]);

      final incremental = await reader.fetch(mid.newChangeToken);
      expect(incremental.records.map((r) => r['text']).toSet(), {
        'v3',
        'v4',
        'v5',
        'v6',
      });
      expect(incremental.deletedUUIDs, [_uuid(2)]);
    });

    test(
      'this device\'s log is cached: pushes do not re-download it',
      () async {
        final writer = storeFor(_devA, maxChunks: 100);
        for (var i = 0; i < 5; i++) {
          await writer.append(records: [_rec(_uuid(i), modifiedAt: i)]);
        }
        expect(drive.listCalls, 1); // the first load only
      },
    );

    test('old tombstones are pruned on compaction', () async {
      final writer = storeFor(_devA, maxChunks: 2);
      final long = DateTime(2026, 1, 1);
      await writer.append(deletions: [_uuid(9)], now: long);
      await writer.append(
        records: [_rec(_uuid(1), modifiedAt: 1)],
        now: long.add(const Duration(days: 100)),
      );
      final fresh = await storeFor(_devB).fetch(null);
      expect(fresh.deletedUUIDs, isEmpty);
      expect(fresh.records, hasLength(1));
    });

    test('idle device logs are found and removed (keyrings kept)', () async {
      final clock = DateTime(2026, 1, 1);
      drive.now = () => clock;
      await storeFor(_devB).append(records: [_rec(_uuid(1), modifiedAt: 1)]);
      await storeFor(
        _devB,
      ).publishKeyring({'kdfSalt': base64Encode(List<int>.filled(32, 2))});
      drive.now = DateTime.now;
      final mine = storeFor(_devA);
      await mine.append(records: [_rec(_uuid(2), modifiedAt: 2)]);
      final idle = await mine.idleDevices(
        const Duration(days: 180),
        now: clock.add(const Duration(days: 200)),
      );
      expect(idle, [_devB]);
      await mine.deleteDeviceLogs(idle);
      expect(
        drive.namesWithPrefix('${DriveSyncLogStore.logPrefix}$_devB'),
        isEmpty,
      );
      expect(
        drive.namesWithPrefix(DriveSyncLogStore.keyringPrefix),
        hasLength(1),
      );
    });

    test('orphan blobs are deleted only when old and unreferenced', () async {
      final tmp = await Directory.systemTemp.createTemp('orphans');
      try {
        final f = File('${tmp.path}/b')..writeAsBytesSync([1]);
        final store = storeFor(_devA);
        drive.now = () => DateTime(2026, 1, 1);
        await store.uploadBlob(_uuid(1), f); // old, referenced
        await store.uploadBlob(_uuid(2), f); // old, orphan
        drive.now = DateTime.now;
        await store.uploadBlob(_uuid(3), f); // new, orphan (maybe in flight)
        final deleted = await store.deleteOrphanBlobs({_uuid(1)});
        expect(deleted, 1);
        expect(drive.namesWithPrefix(DriveSyncLogStore.mediaPrefix).toSet(), {
          '${DriveSyncLogStore.mediaPrefix}${_uuid(1)}.bin',
          '${DriveSyncLogStore.mediaPrefix}${_uuid(3)}.bin',
        });
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('a published keyring is never replaced by another salt', () async {
      final salt = base64Encode(List<int>.filled(32, 4));
      final store = storeFor(_devA);
      await store.publishKeyring({'kdfSalt': salt, 'check': 'c'});
      await store.publishKeyring({
        'kdfSalt': base64Encode(List<int>.filled(32, 9)),
        'check': 'x',
      });
      expect(await store.readKeyring(), containsPair('kdfSalt', salt));
    });

    test('a keyring without a key check is not used', () async {
      final store = storeFor(_devA);
      await store.publishKeyring({
        'kdfSalt': base64Encode(List<int>.filled(32, 4)),
      });
      expect(await store.readKeyring(), isNull);
    });
  });
}
