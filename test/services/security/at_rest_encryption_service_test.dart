import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('AtRestEncryptionService', () {
    late _MockSecureStorage secureStorage;

    setUp(() {
      secureStorage = _MockSecureStorage();
    });

    test('creates and stores a master key when missing', () async {
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          wOptions: any(named: 'wOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((_) async {});

      final service = AtRestEncryptionService(secureStorage: secureStorage);
      await service.init();

      verify(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('encrypt/decrypt roundtrip returns original value', () async {
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          wOptions: any(named: 'wOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((_) async {});

      final service = AtRestEncryptionService(secureStorage: secureStorage);
      await service.init();

      final encrypted = service.encryptField('hello memory');
      expect(encrypted, isNotNull);
      expect(encrypted, startsWith('enc:v1:'));

      final decrypted = service.decryptField(encrypted);
      expect(decrypted, 'hello memory');
    });

    test('returns plaintext as-is when not encrypted', () async {
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          wOptions: any(named: 'wOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((_) async {});

      final service = AtRestEncryptionService(secureStorage: secureStorage);
      await service.init();

      expect(service.decryptField('plain text'), 'plain text');
    });

    test('returns null for malformed encrypted payload', () async {
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          wOptions: any(named: 'wOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((_) async {});

      final service = AtRestEncryptionService(secureStorage: secureStorage);
      await service.init();

      expect(service.isEncryptedValue('enc:v1:broken'), isTrue);
      expect(service.decryptField('enc:v1:broken'), isNull);
    });
  });
}
