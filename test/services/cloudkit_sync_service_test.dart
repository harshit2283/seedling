import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/cloudkit_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.seedling.cloudkit_sync');
  late CloudKitSyncService service;

  setUp(() {
    service = CloudKitSyncService();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('media blob calls pass only an asset id and file paths', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'downloadMediaBlob' ? true : null;
        });

    await service.uploadMediaBlob('asset-1', File('/tmp/blob.enc'));
    final found = await service.downloadMediaBlob(
      'asset-1',
      File('/tmp/out.enc'),
    );
    await service.deleteMediaBlob('asset-1');

    expect(found, isTrue);
    expect(calls.map((c) => c.method), [
      'uploadMediaBlob',
      'downloadMediaBlob',
      'deleteMediaBlob',
    ]);
    expect(calls[0].arguments, <String, dynamic>{
      'assetId': 'asset-1',
      'sourcePath': '/tmp/blob.enc',
    });
    expect(calls[1].arguments, <String, dynamic>{
      'assetId': 'asset-1',
      'destinationPath': '/tmp/out.enc',
    });
  });

  test('isAvailable returns false on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'native-error', message: 'boom');
        });

    final available = await service.isAvailable();

    expect(available, isFalse);
  });

  test('fetchChanges returns null on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'native-error', message: 'boom');
        });

    final result = await service.fetchChanges(changeToken: 'abc');

    expect(result, isNull);
  });
}
