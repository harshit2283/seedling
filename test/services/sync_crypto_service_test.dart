import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void _wireStorage(_MockSecureStorage storage, Map<String, String> values) {
  when(
    () => storage.read(
      key: any(named: 'key'),
      iOptions: any(named: 'iOptions'),
      aOptions: any(named: 'aOptions'),
      lOptions: any(named: 'lOptions'),
      wOptions: any(named: 'wOptions'),
      mOptions: any(named: 'mOptions'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return values[key];
  });
  when(
    () => storage.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
      iOptions: any(named: 'iOptions'),
      aOptions: any(named: 'aOptions'),
      lOptions: any(named: 'lOptions'),
      wOptions: any(named: 'wOptions'),
      mOptions: any(named: 'mOptions'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  });
}

/// Wraps a real PBKDF2 and counts how many times the expensive KDF runs.
class _CountingPbkdf2 extends Pbkdf2 {
  _CountingPbkdf2() : super.constructor();

  final Pbkdf2 _inner = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 1000,
    bits: 256,
  );
  int calls = 0;

  @override
  int get bits => _inner.bits;

  @override
  int get iterations => _inner.iterations;

  @override
  MacAlgorithm get macAlgorithm => _inner.macAlgorithm;

  @override
  Future<SecretKey> deriveKey({
    required SecretKey secretKey,
    required List<int> nonce,
  }) {
    calls++;
    return _inner.deriveKey(secretKey: secretKey, nonce: nonce);
  }
}

/// Builds a record exactly as the v2 format wrote it: per-record key was
/// PBKDF2-SHA256(passphrase, record salt, 210k) and the raw passphrase was
/// kept in secure storage under `seedling_sync_passphrase_v2`.
Future<Map<String, dynamic>> _legacyV2Record(
  String passphrase,
  String text,
) async {
  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  final nonce = List<int>.generate(12, (i) => 100 + i);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(text),
    secretKey: key,
    nonce: nonce,
  );
  return <String, dynamic>{
    'text':
        'syncenc:v1:${base64Encode(nonce)}:${base64Encode(box.cipherText)}:${base64Encode(box.mac.bytes)}',
    'syncEncryptionVersion': 2,
    'syncEncryptionSalt': base64Encode(salt),
  };
}

void main() {
  group('SyncCryptoService key storage', () {
    const passphrase = 'correct horse battery staple';
    const legacyStorageKey = 'seedling_sync_passphrase_v2';

    test('never writes the raw passphrase to secure storage', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(secureStorage: storage);

      await service.setPassphrase(passphrase);

      expect(values.containsKey(legacyStorageKey), isFalse);
      for (final stored in values.values) {
        expect(stored.contains(passphrase), isFalse);
      }
      expect(await service.hasPassphrase(), isTrue);
    });

    test('a fresh service reads records using only the stored key', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      await SyncCryptoService(secureStorage: storage).setPassphrase(passphrase);

      final restarted = SyncCryptoService(secureStorage: storage);
      final encrypted = await restarted.encryptRecordFields(<String, dynamic>{
        'text': 'after restart',
      });
      final decrypted = await SyncCryptoService(
        secureStorage: storage,
      ).decryptRecordFields(encrypted);
      expect(decrypted['text'], 'after restart');
    });

    test('runs PBKDF2 once, not once per pulled record', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final pbkdf2 = _CountingPbkdf2();
      final writer = SyncCryptoService(secureStorage: storage, pbkdf2: pbkdf2);
      await writer.setPassphrase(passphrase);

      // Records from many distinct sync batches (distinct salts).
      final records = <Map<String, dynamic>>[];
      for (var i = 0; i < 10; i++) {
        records.add(
          await writer.encryptRecordFields(<String, dynamic>{'text': 'r$i'}),
        );
      }
      final pbkdf2Reader = _CountingPbkdf2();
      final reader = SyncCryptoService(
        secureStorage: storage,
        pbkdf2: pbkdf2Reader,
      );
      for (var i = 0; i < records.length; i++) {
        final decrypted = await reader.decryptRecordFields(records[i]);
        expect(decrypted['text'], 'r$i');
      }

      expect(pbkdf2.calls, 1);
      expect(pbkdf2Reader.calls, 0);
    });

    test(
      'migrates a stored legacy passphrase and still reads v2 records',
      () async {
        final storage = _MockSecureStorage();
        final values = <String, String>{legacyStorageKey: passphrase};
        _wireStorage(storage, values);
        final legacyRecord = await _legacyV2Record(passphrase, 'old memory');

        final service = SyncCryptoService(secureStorage: storage);
        expect(await service.hasPassphrase(), isTrue);
        final decrypted = await service.decryptRecordFields(legacyRecord);
        expect(decrypted['text'], 'old memory');

        // Raw passphrase is gone from storage, replaced by derived key.
        expect(values.containsKey(legacyStorageKey), isFalse);
        for (final stored in values.values) {
          expect(stored.contains(passphrase), isFalse);
        }

        // New records still round-trip on the migrated key, and a device
        // that set the same passphrase directly can read them.
        final fresh = await service.encryptRecordFields(<String, dynamic>{
          'text': 'new memory',
        });
        final otherStorage = _MockSecureStorage();
        _wireStorage(otherStorage, <String, String>{});
        final otherDevice = SyncCryptoService(secureStorage: otherStorage);
        await otherDevice.setPassphrase(passphrase);
        expect(
          (await otherDevice.decryptRecordFields(fresh))['text'],
          'new memory',
        );
        expect(
          (await otherDevice.decryptRecordFields(legacyRecord))['text'],
          'old memory',
        );
      },
    );

    test(
      'v2 records in a later session ask for the passphrase again',
      () async {
        final storage = _MockSecureStorage();
        final values = <String, String>{legacyStorageKey: passphrase};
        _wireStorage(storage, values);
        final legacyRecord = await _legacyV2Record(passphrase, 'old memory');
        await SyncCryptoService(
          secureStorage: storage,
        ).encryptRecordFields(<String, dynamic>{'text': 'trigger migration'});

        final nextLaunch = SyncCryptoService(secureStorage: storage);
        await expectLater(
          () => nextLaunch.decryptRecordFields(legacyRecord),
          throwsA(isA<SyncPassphraseReentryRequiredException>()),
        );

        await nextLaunch.setPassphrase(passphrase);
        expect(
          (await nextLaunch.decryptRecordFields(legacyRecord))['text'],
          'old memory',
        );
      },
    );
  });

  group('SyncCryptoService', () {
    test(
      'encrypts and decrypts sync fields with current version marker',
      () async {
        final storage = _MockSecureStorage();
        final values = <String, String>{};
        _wireStorage(storage, values);
        final service = SyncCryptoService(secureStorage: storage);
        await service.setPassphrase('correct horse battery staple');

        final record = <String, dynamic>{
          'syncUUID': '550e8400-e29b-41d4-a716-446655440099',
          'text': 'private text',
          'title': 'private title',
          'context': 'private context',
          'mood': 'calm',
          'tags': 'life,gratitude',
          'transcription': 'spoken words',
          'detectedTheme': 'family',
          'mediaPath': '/tmp/file.m4a',
        };

        final encrypted = await service.encryptRecordFields(record);
        expect(
          encrypted['syncEncryptionVersion'],
          SyncCryptoService.syncEncryptionVersion,
        );
        expect(encrypted['syncEncryptionSalt'], isA<String>());
        expect(encrypted['text'], isNot('private text'));
        expect(encrypted['mediaPath'], '/tmp/file.m4a');

        final decrypted = await service.decryptRecordFields(encrypted);
        expect(decrypted['text'], 'private text');
        expect(decrypted['title'], 'private title');
        expect(decrypted['context'], 'private context');
        expect(decrypted['mood'], 'calm');
        expect(decrypted['tags'], 'life,gratitude');
        expect(decrypted['transcription'], 'spoken words');
        expect(decrypted['detectedTheme'], 'family');
        expect(decrypted['mediaPath'], '/tmp/file.m4a');
      },
    );

    test(
      'uses passphrase-derived key that decrypts across services/devices',
      () async {
        final storageA = _MockSecureStorage();
        final valuesA = <String, String>{};
        _wireStorage(storageA, valuesA);
        final serviceA = SyncCryptoService(secureStorage: storageA);
        await serviceA.setPassphrase('same passphrase everywhere');

        final storageB = _MockSecureStorage();
        final valuesB = <String, String>{};
        _wireStorage(storageB, valuesB);
        final serviceB = SyncCryptoService(secureStorage: storageB);
        await serviceB.setPassphrase('same passphrase everywhere');

        final encrypted = await serviceA.encryptRecordFields(<String, dynamic>{
          'text': 'cross-device secret',
        });
        final decrypted = await serviceB.decryptRecordFields(encrypted);

        expect(decrypted['text'], 'cross-device secret');
      },
    );

    test(
      'reuses the same session salt across records in one sync batch',
      () async {
        final storage = _MockSecureStorage();
        final values = <String, String>{};
        _wireStorage(storage, values);
        final service = SyncCryptoService(secureStorage: storage);
        await service.setPassphrase('same passphrase everywhere');

        final session = await service.createEncryptionSession();
        final first = await service.encryptRecordFields(<String, dynamic>{
          'text': 'first',
        }, session: session);
        final second = await service.encryptRecordFields(<String, dynamic>{
          'text': 'second',
        }, session: session);

        expect(
          first['syncEncryptionSalt'],
          equals(second['syncEncryptionSalt']),
        );
        expect(first['text'], isNot(equals(second['text'])));
      },
    );

    test('treats legacy records without version as plaintext', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(secureStorage: storage);

      final legacy = await service.decryptRecordFields(<String, dynamic>{
        'syncUUID': '550e8400-e29b-41d4-a716-446655440098',
        'text': 'legacy plaintext',
      });

      expect(legacy['text'], 'legacy plaintext');
      expect(legacy['syncEncryptionVersion'], isNull);
    });

    test('throws user-facing error when passphrase is missing', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(secureStorage: storage);

      await expectLater(
        () => service.encryptRecordFields(<String, dynamic>{'text': 'hello'}),
        throwsA(isA<SyncPassphraseMissingException>()),
      );
    });
  });
}
