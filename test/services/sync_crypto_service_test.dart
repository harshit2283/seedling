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

void main() {
  group('SyncCryptoService', () {
    test('encrypts and decrypts sync fields with version 2 marker', () async {
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
    });

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
