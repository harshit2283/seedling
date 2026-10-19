import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/drive_sync_log.dart';
import 'package:seedling/core/services/sync/google_drive_sync_service.dart';

/// In-memory appData folder. Every call yields to the event loop first, so
/// concurrent pushes from several "devices" genuinely interleave.
class _MemoryDrive implements DriveFileStore {
  final files = <String, ({String name, List<int> bytes})>{};
  var _nextId = 0;

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    await Future<void>.delayed(Duration.zero);
    return [
      for (final MapEntry(:key, :value) in files.entries)
        if (value.name.startsWith(prefix))
          DriveFileInfo(id: key, name: value.name),
    ];
  }

  @override
  Future<List<int>?> read(String fileId) async {
    await Future<void>.delayed(Duration.zero);
    return files[fileId]?.bytes;
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    await Future<void>.delayed(Duration.zero);
    final id = 'f${_nextId++}';
    files[id] = (name: name, bytes: bytes);
    return id;
  }

  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {
    await Future<void>.delayed(Duration.zero);
    files[fileId] = (name: files[fileId]!.name, bytes: bytes);
  }
}

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
  late _MemoryDrive drive;
  late GoogleDriveSyncService a;
  late GoogleDriveSyncService b;
  late GoogleDriveSyncService c;

  setUp(() {
    drive = _MemoryDrive();
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

  test('a batch push is a single write', () async {
    await a.saveRecords([
      for (var i = 0; i < 50; i++) _rec(_uuid(i), modifiedAt: i),
    ]);
    expect(drive.files, hasLength(1));
    final log = jsonDecode(utf8.decode(drive.files.values.single.bytes));
    expect(log['seq'], 50);
  });

  test('old timestamp tokens fall back to a full fetch', () async {
    await a.saveRecord(_rec(_uuid(1), modifiedAt: 10, text: 'kept'));
    final fetched = await c.fetchChanges(changeToken: '99999999999999');
    expect(fetched!.records.map((r) => r['text']), ['kept']);
  });

  test('legacy v1 document is still read, once per change', () async {
    final legacy = {
      'metadataVersion': 1,
      'updatedAt': 500,
      'records': {_uuid(7): _rec(_uuid(7), modifiedAt: 1, text: 'from v1')},
      'deletions': {_uuid(8): 400},
      'quarantine': <String, dynamic>{},
    };
    await drive.create(
      DriveSyncLogStore.legacyFileName,
      utf8.encode(jsonEncode(legacy)),
    );

    final first = await c.fetchChanges();
    expect(first!.records.map((r) => r['text']), ['from v1']);
    expect(first.deletedUUIDs, [_uuid(8)]);

    final second = await c.fetchChanges(changeToken: first.newChangeToken);
    expect(second!.records, isEmpty);
    expect(second.deletedUUIDs, isEmpty);
  });

  test('key salt: first publisher wins and racing devices agree', () async {
    expect(await a.readKdfSalt(), isNull);
    final saltA = base64Encode(List<int>.filled(32, 9));
    final saltB = base64Encode(List<int>.filled(32, 3));
    final results = await Future.wait([
      a.publishKdfSalt(saltA),
      b.publishKdfSalt(saltB),
    ]);
    // Both devices, and any later reader, settle on one salt.
    expect(results[0], results[1]);
    expect(await c.readKdfSalt(), results[0]);
    // Publishing again never replaces it.
    expect(
      await c.publishKdfSalt(base64Encode(List<int>.filled(32, 1))),
      results[0],
    );
  });

  test('an unreadable log from one device does not block the others', () async {
    await drive.create('${DriveSyncLogStore.logPrefix}broken.json', [1, 2, 3]);
    await b.saveRecord(_rec(_uuid(1), modifiedAt: 1, text: 'ok'));
    final fetched = await c.fetchChanges();
    expect(fetched!.records.map((r) => r['text']), ['ok']);
  });
}
