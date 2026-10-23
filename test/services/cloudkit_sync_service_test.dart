import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/cloudkit_sync_service.dart';
import 'package:seedling/core/services/sync/drive_sync_log.dart';

/// The CloudKit custom zone as the plugin exposes it: files by id (= name).
class _FakeZone {
  final files = <String, List<int>>{};

  Future<Object?> handle(MethodCall call) async {
    final args = Map<String, Object?>.from(call.arguments as Map? ?? {});
    switch (call.method) {
      case 'fsList':
        final prefix = args['prefix']! as String;
        return [
          for (final id in files.keys)
            if (id.startsWith(prefix)) {'id': id, 'name': id},
        ];
      case 'fsWrite':
        files[args['id']! as String] = await File(
          args['sourcePath']! as String,
        ).readAsBytes();
        return true;
      case 'fsRead':
        final bytes = files[args['id']! as String];
        if (bytes == null) return false;
        await File(args['destinationPath']! as String).writeAsBytes(bytes);
        return true;
      case 'fsExists':
        final id = args['id']! as String;
        return files.containsKey(id)
            ? {'id': id, 'name': id, 'createdAt': 0}
            : null;
      case 'fsDelete':
        files.remove(args['id']! as String); // missing is fine
        return true;
    }
    throw MissingPluginException(call.method);
  }
}

class _BrokenStore implements DriveFileStore {
  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async =>
      throw PlatformException(code: 'NETWORK_UNAVAILABLE');
  @override
  Future<DriveFileInfo?> findByName(String name) async => null;
  @override
  Future<void> overwriteFromFile(String fileId, File source) async {}
  @override
  Future<List<int>?> read(String fileId) async => null;
  @override
  Future<String> create(String name, List<int> bytes) async => name;
  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {}
  @override
  Future<String> createFromFile(String name, File source) async => name;
  @override
  Future<void> downloadTo(String fileId, File target) async {}
  @override
  Future<void> delete(String fileId) async {}
}

Map<String, dynamic> _rec(String uuid, {String? mediaAssetId}) => {
  'syncUUID': uuid,
  'modifiedAt': 1,
  'syncEncryptionVersion': 4,
  'mediaAssetId': mediaAssetId,
  'mediaKey': mediaAssetId == null ? null : 'syncenc:v1:k',
};

const _uuid1 = '550e8400-e29b-41d4-a716-446655440081';
const _asset = '550e8400-e29b-41d4-a716-446655440082';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.seedling.cloudkit_sync');
  late _FakeZone zone;

  setUp(() {
    zone = _FakeZone();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, zone.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  CloudKitSyncService device(String id) =>
      CloudKitSyncService.withStore(CloudKitFileStore(), deviceId: id);

  test('deletions propagate to other devices (no resurrection)', () async {
    final a = device('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final b = device('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    await a.saveRecord(_rec(_uuid1));
    final first = await b.fetchChanges();
    expect(first!.records.single['syncUUID'], _uuid1);

    await a.deleteRecord(_uuid1);
    final second = await b.fetchChanges(changeToken: first.newChangeToken);
    expect(second!.deletedUUIDs, [_uuid1]);
    expect(second.records, isEmpty);
    // Incremental: nothing new, nothing delivered again.
    final third = await b.fetchChanges(changeToken: second.newChangeToken);
    expect(third!.records, isEmpty);
    expect(third.deletedUUIDs, isEmpty);
  });

  test('media id and key round-trip unchanged', () async {
    final a = device('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final b = device('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    await a.saveRecord(_rec(_uuid1, mediaAssetId: _asset));
    final pulled = (await b.fetchChanges())!.records.single;
    expect(pulled['mediaAssetId'], _asset);
    expect(pulled['mediaKey'], 'syncenc:v1:k');
  });

  test('deleting something already gone succeeds', () async {
    final a = device('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    await a.deleteMediaBlob(_asset);
    await a.deleteRecord(_uuid1);
  });

  test(
    'backend failures surface instead of looking like "no changes"',
    () async {
      final broken = CloudKitSyncService.withStore(
        _BrokenStore(),
        deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      await expectLater(
        broken.fetchChanges(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test('file store passes only ids, names and file paths to native', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return zone.handle(call);
        });
    final store = CloudKitFileStore();
    await store.create('seedling_x', [1, 2, 3]);
    expect(await store.read('seedling_x'), [1, 2, 3]);
    await store.delete('seedling_x');
    expect(calls.map((c) => c.method), ['fsWrite', 'fsRead', 'fsDelete']);
    expect((calls.first.arguments as Map)['id'], 'seedling_x');
    expect((calls.first.arguments as Map).keys.toSet(), {
      'id',
      'name',
      'sourcePath',
    });
  });

  test('pushes and blob calls use exact lookups, not zone scans', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          return zone.handle(call);
        });
    final a = device('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final tmp = await Directory.systemTemp.createTemp('ck_blob');
    try {
      for (var i = 0; i < 5; i++) {
        await a.saveRecord(_rec('550e8400-e29b-41d4-a716-44665544009$i'));
      }
      final blob = File('${tmp.path}/b')..writeAsBytesSync([1, 2]);
      await a.uploadMediaBlob(_asset, blob);
      await a.downloadMediaBlob(_asset, File('${tmp.path}/out'));
      await a.deleteMediaBlob(_asset);
    } finally {
      await tmp.delete(recursive: true);
    }
    // One listing to load this device's log once; everything else is by id.
    expect(calls.where((m) => m == 'fsList'), hasLength(1));
  });

  test('throttling is retried, honouring retry-after', () async {
    final sleeps = <Duration>[];
    var failures = 2;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failures-- > 0) {
            throw PlatformException(
              code: 'RATE_LIMITED',
              details: {'retryAfterSeconds': 3.0},
            );
          }
          return zone.handle(call);
        });
    final store = CloudKitFileStore(sleep: (d) async => sleeps.add(d));
    expect(await store.findByName('nothing'), isNull);
    expect(sleeps, [const Duration(seconds: 3), const Duration(seconds: 3)]);
  });

  test('non-throttling errors are not retried', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          throw PlatformException(code: 'QUOTA_EXCEEDED');
        });
    final store = CloudKitFileStore(sleep: (_) async {});
    await expectLater(store.findByName('x'), throwsA(isA<PlatformException>()));
    expect(calls, 1);
  });
}
