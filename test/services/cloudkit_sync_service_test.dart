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

  test('uploadAsset uses native CloudKit argument contract', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return '/remote/path';
        });

    final result = await service.uploadAsset('/tmp/local.m4a', 'uuid-1');

    expect(result, '/remote/path');
    expect(captured?.method, 'uploadAsset');
    expect(captured?.arguments, <String, dynamic>{
      'syncUUID': 'uuid-1',
      'filePath': '/tmp/local.m4a',
      'fieldName': 'mediaAsset',
    });
  });

  test('downloadAsset uses destinationPath and fieldName keys', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return '/tmp/dest.m4a';
        });

    final result = await service.downloadAsset('uuid-2', '/tmp/dest.m4a');

    expect(result, '/tmp/dest.m4a');
    expect(captured?.method, 'downloadAsset');
    expect(captured?.arguments, <String, dynamic>{
      'syncUUID': 'uuid-2',
      'destinationPath': '/tmp/dest.m4a',
      'fieldName': 'mediaAsset',
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
