import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/security/ios_data_protection.dart';
import 'package:seedling/core/services/security/secure_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Records writes along with the iOS accessibility they were made with.
class _Recorder {
  final Map<String, String> values;
  final List<(String key, String? accessibility)> writes = [];
  _Recorder(this.values);
}

_Recorder _wire(_MockSecureStorage storage, Map<String, String> values) {
  final recorder = _Recorder(values);
  when(
    () => storage.read(
      key: any(named: 'key'),
      iOptions: any(named: 'iOptions'),
      aOptions: any(named: 'aOptions'),
      lOptions: any(named: 'lOptions'),
      webOptions: any(named: 'webOptions'),
      mOptions: any(named: 'mOptions'),
      wOptions: any(named: 'wOptions'),
    ),
  ).thenAnswer((inv) async => values[inv.namedArguments[#key] as String]);
  when(
    () => storage.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
      iOptions: any(named: 'iOptions'),
      aOptions: any(named: 'aOptions'),
      lOptions: any(named: 'lOptions'),
      webOptions: any(named: 'webOptions'),
      mOptions: any(named: 'mOptions'),
      wOptions: any(named: 'wOptions'),
    ),
  ).thenAnswer((inv) async {
    final key = inv.namedArguments[#key] as String;
    final value = inv.namedArguments[#value] as String?;
    final options = inv.namedArguments[#iOptions] as IOSOptions?;
    recorder.writes.add((key, options?.toMap()['accessibility']));
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  });
  return recorder;
}

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

    test(
      'migration re-writes existing secrets with new accessibility',
      () async {
        final storage = _MockSecureStorage();
        final recorder = _wire(storage, {
          'seedling_local_master_key_v1': 'local-key',
          'seedling_sync_key_v3': '{"key":"k"}',
        });

        await SecureStorageAccessibilityMigration(storage: storage).run();

        expect(recorder.writes, [
          ('seedling_local_master_key_v1', 'first_unlock_this_device'),
          ('seedling_sync_key_v3', 'first_unlock_this_device'),
          (
            SecureStorageAccessibilityMigration.markerKey,
            'first_unlock_this_device',
          ),
        ]);
        expect(recorder.values['seedling_local_master_key_v1'], 'local-key');
      },
    );

    test('migration runs once', () async {
      final storage = _MockSecureStorage();
      final recorder = _wire(storage, {
        'seedling_local_master_key_v1': 'local-key',
      });
      final migration = SecureStorageAccessibilityMigration(storage: storage);

      await migration.run();
      final firstRunWrites = recorder.writes.length;
      await migration.run();

      expect(recorder.writes.length, firstRunWrites);
    });

    test('migration covers every service key', () {
      expect(
        SecureStorageAccessibilityMigration.knownKeys,
        containsAll(<String>[
          'seedling_local_master_key_v1',
          'clock_guard_max_observed_now_v1',
          'seedling_sync_passphrase_v2',
          'seedling_sync_key_v3',
        ]),
      );
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
      ).hardenDirectory('/data/objectbox');

      expect(calls.map((c) => c.method), ['protectPath', 'excludeFromBackup']);
      expect(calls[0].arguments, {
        'path': '/data/objectbox',
        'recursive': true,
      });
      expect(calls[1].arguments, {'path': '/data/objectbox'});
    });

    test('is a no-op off iOS', () async {
      await IosDataProtection(
        channel: channel,
        isIOS: false,
      ).hardenDirectory('/data/objectbox');
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
