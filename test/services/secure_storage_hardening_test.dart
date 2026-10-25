import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/ios_data_protection.dart';
import 'package:seedling/core/services/security/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seedling secure storage', () {
    test('uses device-only, after-first-unlock keychain accessibility', () {
      expect(
        createSeedlingSecureStorage().iOptions.toMap()['accessibility'],
        'first_unlock_this_device',
      );
    });

    test('lib/ constructs FlutterSecureStorage only via the factory', () {
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('security/secure_storage.dart')) continue;
        if (file.readAsStringSync().contains('FlutterSecureStorage(')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('IosDataProtection', () {
    const channel = MethodChannel('test/file_protection');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('protects and excludes a directory from backup on iOS', () async {
      await IosDataProtection(
        channel: channel,
        isIOS: true,
      ).hardenDirectory('/data/database');

      expect(calls.map((c) => c.method), ['protectPath', 'excludeFromBackup']);
      expect(calls[0].arguments, {'path': '/data/database', 'recursive': true});
      expect(calls[1].arguments, {'path': '/data/database'});
    });

    test('is a no-op off iOS', () async {
      await IosDataProtection(
        channel: channel,
        isIOS: false,
      ).hardenDirectory('/data/database');
      expect(calls, isEmpty);
    });

    test('never throws when the native side fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'FAILED');
          });
      await expectLater(
        IosDataProtection(
          channel: channel,
          isIOS: true,
        ).hardenDirectory('/data/media'),
        completes,
      );
    });
  });
}
