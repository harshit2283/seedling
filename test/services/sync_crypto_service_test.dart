// Real PBKDF2 (210k iterations) runs several times per test; give it room
// when the whole suite runs in parallel.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';

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

/// An initially empty shared keyring (the account's sync space).
class _MemKeyring implements SyncKeyring {
  Map<String, dynamic>? stored;

  @override
  Future<Map<String, dynamic>?> read() async => stored;

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> keyring) async =>
      stored ??= Map<String, dynamic>.from(keyring);
}

void main() {
  group('SyncCryptoService key storage', () {
    const passphrase = 'correct horse battery staple';

    test('never writes the raw passphrase to secure storage', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: _MemKeyring(),
      );

      await service.setPassphrase(passphrase);

      for (final stored in values.values) {
        expect(stored.contains(passphrase), isFalse);
      }
      expect(await service.hasPassphrase(), isTrue);
    });

    test('a fresh service reads records using only the stored key', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final keyring = _MemKeyring();
      await SyncCryptoService(
        secureStorage: storage,
        keyring: keyring,
      ).setPassphrase(passphrase);

      final restarted = SyncCryptoService(
        secureStorage: storage,
        keyring: keyring,
      );
      final encrypted = await restarted.encryptRecordFields(<String, dynamic>{
        'text': 'after restart',
      });
      final decrypted = await SyncCryptoService(
        secureStorage: storage,
        keyring: keyring,
      ).decryptRecordFields(encrypted);
      expect(decrypted['text'], 'after restart');
    });

    test('runs PBKDF2 once, not once per pulled record', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final pbkdf2 = _CountingPbkdf2();
      final keyring = _MemKeyring();
      final writer = SyncCryptoService(
        secureStorage: storage,
        pbkdf2: pbkdf2,
        keyring: keyring,
      );
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
        keyring: keyring,
      );
      for (var i = 0; i < records.length; i++) {
        final decrypted = await reader.decryptRecordFields(records[i]);
        expect(decrypted['text'], 'r$i');
      }

      expect(pbkdf2.calls, 1);
      expect(pbkdf2Reader.calls, 0);
    });
  });

  group('SyncCryptoService per-user key salt', () {
    const passphrase = 'correct horse battery staple';

    test(
      'devices sharing the keyring salt interoperate; others cannot',
      () async {
        final storageA = _MockSecureStorage();
        final valuesA = <String, String>{};
        _wireStorage(storageA, valuesA);
        final account = _MemKeyring();
        final deviceA = SyncCryptoService(
          secureStorage: storageA,
          keyring: account,
        );
        await deviceA.setPassphrase(passphrase);

        final storageB = _MockSecureStorage();
        _wireStorage(storageB, <String, String>{});
        final deviceB = SyncCryptoService(
          secureStorage: storageB,
          keyring: account,
        );
        await deviceB.setPassphrase(passphrase);

        final encrypted = await deviceA.encryptRecordFields(<String, dynamic>{
          'text': 'shared',
        });
        expect(encrypted['syncEncryptionVersion'], 1);
        expect(
          (await deviceB.decryptRecordFields(encrypted))['text'],
          'shared',
        );
        final accountSalt = base64Decode(account.stored!['kdfSalt'] as String);
        expect(accountSalt, hasLength(32));
        expect(await deviceB.usesKdfSalt(accountSalt), isTrue);

        // Same passphrase, different account (different salt): the key, and so
        // any precomputed cracking work, is not shared.
        final storageC = _MockSecureStorage();
        _wireStorage(storageC, <String, String>{});
        final otherUser = SyncCryptoService(
          secureStorage: storageC,
          keyring: _MemKeyring(),
        );
        await otherUser.setPassphrase(passphrase);
        await expectLater(
          () => otherUser.decryptRecordFields(encrypted),
          throwsA(isA<SyncPayloadCryptoException>()),
        );
        // The stored key material records the per-user salt, not the app one.
        final material =
            jsonDecode(valuesA['seedling_sync_key']!) as Map<String, dynamic>;
        expect(base64Decode(material['salt'] as String), accountSalt);
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
        final service = SyncCryptoService(
          secureStorage: storage,
          keyring: _MemKeyring(),
        );
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
        final account = _MemKeyring();
        final serviceA = SyncCryptoService(
          secureStorage: storageA,
          keyring: account,
        );
        await serviceA.setPassphrase('same passphrase everywhere');

        final storageB = _MockSecureStorage();
        final valuesB = <String, String>{};
        _wireStorage(storageB, valuesB);
        final serviceB = SyncCryptoService(
          secureStorage: storageB,
          keyring: account,
        );
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
        final service = SyncCryptoService(
          secureStorage: storage,
          keyring: _MemKeyring(),
        );
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

    test('rejects records without an encryption version', () async {
      final storage = _MockSecureStorage();
      _wireStorage(storage, <String, String>{});
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: _MemKeyring(),
      );
      await service.setPassphrase('correct horse battery staple');

      // Unversioned "plaintext" must never be imported as-is.
      await expectLater(
        () => service.decryptRecordFields(<String, dynamic>{
          'syncUUID': '550e8400-e29b-41d4-a716-446655440098',
          'text': 'injected plaintext',
        }),
        throwsA(isA<SyncPayloadCryptoException>()),
      );
    });

    test('encrypts manual links and decrypts a batch with one key', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: _MemKeyring(),
      );
      await service.setPassphrase('correct horse battery staple');

      final session = await service.createEncryptionSession();
      final records = [
        for (var i = 0; i < 3; i++)
          await service.encryptRecordFields(<String, dynamic>{
            'text': 'note $i',
            'manualLinkIds': '550e8400-e29b-41d4-a716-44665544000$i',
          }, session: session),
      ];
      expect(records.first['manualLinkIds'], startsWith('syncenc:v1:'));
      final decrypted = [
        for (final r in records) await service.decryptRecordFields(r),
      ];
      expect(decrypted.map((r) => r['text']), ['note 0', 'note 1', 'note 2']);
      expect(
        decrypted.last['manualLinkIds'],
        '550e8400-e29b-41d4-a716-446655440002',
      );
    });

    test('the media file key is encrypted in the record', () async {
      final storage = _MockSecureStorage();
      _wireStorage(storage, <String, String>{});
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: _MemKeyring(),
      );
      await service.setPassphrase('correct horse battery staple');
      const fileKey = 'q83vEjRWeJq83vEjRWeJq83vEjRWeJq83vEjRWeJA==';
      final encrypted = await service.encryptRecordFields(<String, dynamic>{
        'mediaAssetId': '550e8400-e29b-41d4-a716-446655440077',
        'mediaKey': fileKey,
      });
      expect(encrypted['mediaKey'], startsWith('syncenc:v1:'));
      expect(encrypted['mediaAssetId'], '550e8400-e29b-41d4-a716-446655440077');
      expect(
        (await service.decryptRecordFields(encrypted))['mediaKey'],
        fileKey,
      );
    });

    test('throws user-facing error when passphrase is missing', () async {
      final storage = _MockSecureStorage();
      final values = <String, String>{};
      _wireStorage(storage, values);
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: _MemKeyring(),
      );

      await expectLater(
        () => service.encryptRecordFields(<String, dynamic>{'text': 'hello'}),
        throwsA(isA<SyncPassphraseMissingException>()),
      );
    });
  });

  group('SyncCryptoService record authentication and keyring checks', () {
    const passphrase = 'correct horse battery staple';

    Future<SyncCryptoService> device(SyncKeyring keyring) async {
      final storage = _MockSecureStorage();
      _wireStorage(storage, <String, String>{});
      final service = SyncCryptoService(
        secureStorage: storage,
        keyring: keyring,
      );
      await service.setPassphrase(passphrase);
      return service;
    }

    Map<String, dynamic> record() => <String, dynamic>{
      'syncUUID': '550e8400-e29b-41d4-a716-446655440061',
      'typeIndex': 0,
      'createdAt': 1700000000000,
      'modifiedAt': 1700000000000,
      'isDeleted': false,
      'capsuleUnlockDate': null,
      'mediaAssetId': null,
      'text': 'a quiet morning',
      'title': 'dawn',
    };

    test('a wrong passphrase is rejected by the key check', () async {
      final keyring = _MemKeyring();
      await device(keyring);
      final storage = _MockSecureStorage();
      _wireStorage(storage, <String, String>{});
      final other = SyncCryptoService(secureStorage: storage, keyring: keyring);
      await expectLater(
        other.setPassphrase('not the same passphrase'),
        throwsA(isA<SyncWrongPassphraseException>()),
      );
      expect(await other.hasPassphrase(), isFalse);
      // The right one is accepted and matches the keyring.
      await other.setPassphrase(passphrase);
      expect(await other.matchesKeyring(keyring.stored!), isTrue);
    });

    test('plaintext metadata is authenticated', () async {
      final service = await device(_MemKeyring());
      final sealed = await service.encryptRecordFields(record());
      expect(sealed['syncMac'], isA<String>());
      for (final tamper in <void Function(Map<String, dynamic>)>[
        (r) => r['isDeleted'] = true,
        (r) => r['modifiedAt'] = 1800000000000,
        (r) => r['capsuleUnlockDate'] = 1900000000000,
        (r) => r['mediaAssetId'] = '550e8400-e29b-41d4-a716-446655440062',
        (r) => r['typeIndex'] = 3,
        (r) => r.remove('title'),
      ]) {
        final forged = Map<String, dynamic>.from(sealed);
        tamper(forged);
        await expectLater(
          service.decryptRecordFields(forged),
          throwsA(isA<SyncPayloadCryptoException>()),
        );
      }
      expect(
        (await service.decryptRecordFields(sealed))['text'],
        'a quiet morning',
      );
    });

    test(
      'a field ciphertext cannot be moved to another record or field',
      () async {
        final service = await device(_MemKeyring());
        final session = await service.createEncryptionSession();
        final a = await service.encryptRecordFields(record(), session: session);
        final b = await service.encryptRecordFields({
          ...record(),
          'syncUUID': '550e8400-e29b-41d4-a716-446655440063',
        }, session: session);
        // Swap text between records; re-MACing is not possible without the
        // key, and a record without its MAC is rejected outright.
        final swapped = Map<String, dynamic>.from(b)..['text'] = a['text'];
        await expectLater(
          service.decryptRecordFields(swapped),
          throwsA(isA<SyncPayloadCryptoException>()),
        );
        final downgraded = Map<String, dynamic>.from(a)..remove('syncMac');
        await expectLater(
          service.decryptRecordFields(downgraded),
          throwsA(isA<SyncPayloadCryptoException>()),
        );
      },
    );
  });
}
