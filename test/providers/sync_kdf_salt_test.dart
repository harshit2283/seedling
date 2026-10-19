// Real PBKDF2 (210k iterations) runs several times per test; give it room
// when the whole suite runs in parallel.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers/sync_providers.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';

class _KeyringBackend extends SyncBackend {
  Map<String, dynamic>? stored;
  var calls = 0;

  @override
  Future<bool> isAvailable() async {
    calls++;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> readKeyring() async => stored;

  @override
  Future<Map<String, dynamic>> publishKeyring(Map<String, dynamic> k) async =>
      stored ??= k;

  @override
  Future<String> getAccountStatus() async => 'test';
  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {}
  @override
  Future<void> deleteRecord(String syncUUID) async {}
  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const passphrase = 'correct horse battery staple';

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  SyncCryptoService serviceFor(
    _KeyringBackend backend, {
    bool optedIn = true,
  }) => SyncCryptoService(
    secureStorage: const FlutterSecureStorage(),
    keyring: BackendSyncKeyring(
      cloudSyncEnabled: () => optedIn,
      backend: () => backend,
    ),
  );

  test('does not contact the backend before the cloud-sync opt-in', () async {
    final backend = _KeyringBackend();
    await expectLater(
      serviceFor(backend, optedIn: false).setPassphrase(passphrase),
      throwsA(isA<SyncPayloadCryptoException>()),
    );
    expect(backend.calls, 0);
    expect(backend.stored, isNull);
  });

  test('creates one random salt with a key check, reused afterwards', () async {
    final backend = _KeyringBackend();
    await serviceFor(backend).setPassphrase(passphrase);
    final keyring = backend.stored!;
    expect(base64Decode(keyring['kdfSalt'] as String), hasLength(32));
    expect(keyring['check'], startsWith('syncenc:v1:'));

    // Another device with the right passphrase joins without changing it.
    FlutterSecureStorage.setMockInitialValues({});
    await serviceFor(backend).setPassphrase(passphrase);
    expect(backend.stored, same(keyring));
  });

  test('a wrong passphrase is rejected and nothing is stored', () async {
    final backend = _KeyringBackend();
    await serviceFor(backend).setPassphrase(passphrase);

    FlutterSecureStorage.setMockInitialValues({});
    final other = serviceFor(backend);
    await expectLater(
      other.setPassphrase('a different passphrase'),
      throwsA(isA<SyncWrongPassphraseException>()),
    );
    expect(await other.hasPassphrase(), isFalse);
  });
}
