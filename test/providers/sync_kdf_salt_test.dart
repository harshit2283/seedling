import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers/sync_providers.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:seedling/core/services/sync/sync_crypto_service.dart';

class _KeyringBackend extends SyncBackend {
  String? stored;
  var calls = 0;

  @override
  Future<bool> isAvailable() async {
    calls++;
    return true;
  }

  @override
  Future<String?> readKdfSalt() async => stored;

  @override
  Future<String> publishKdfSalt(String salt) async => stored ??= salt;

  @override
  Future<String> getAccountStatus() async => 'test';
  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {}
  @override
  Future<void> deleteRecord(String syncUUID) async {}
  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async => null;
  @override
  Future<String?> downloadAsset(String syncUUID, String targetPath) async =>
      null;
}

void main() {
  test('does not contact the backend before the cloud-sync opt-in', () async {
    final backend = _KeyringBackend();
    await expectLater(
      resolveSyncKdfSalt(cloudSyncEnabled: false, backend: backend),
      throwsA(isA<SyncPayloadCryptoException>()),
    );
    expect(backend.calls, 0);
    expect(backend.stored, isNull);
  });

  test('creates one random 32-byte salt and reuses it afterwards', () async {
    final backend = _KeyringBackend();
    final first = await resolveSyncKdfSalt(
      cloudSyncEnabled: true,
      backend: backend,
    );
    expect(first, hasLength(32));
    expect(base64Decode(backend.stored!), first);
    final second = await resolveSyncKdfSalt(
      cloudSyncEnabled: true,
      backend: backend,
    );
    expect(second, first);

    // A different account gets a different salt.
    final other = await resolveSyncKdfSalt(
      cloudSyncEnabled: true,
      backend: _KeyringBackend(),
    );
    expect(other, isNot(first));
  });
}
