import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

/// Holds the random 256-bit key that encrypts the whole local database
/// (SQLCipher). It lives only in the device-only Keychain / Keystore item
/// created by [createSeedlingSecureStorage], so a device backup never carries
/// it (and the database file itself is excluded from backups too).
class DatabaseKeyStore {
  static const keyStorageId = 'seedling_database_key_v1';
  static const keyLength = 32;

  final FlutterSecureStorage _secureStorage;

  DatabaseKeyStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? createSeedlingSecureStorage();

  /// The stored key, or null when none has been created on this device.
  ///
  /// A failing read (e.g. a keychain that is not available yet) throws: the
  /// caller must never take an error for "no key" and mint a new one.
  Future<Uint8List?> read() async {
    final stored = await _secureStorage.read(key: keyStorageId);
    if (stored == null || stored.isEmpty) return null;
    final key = base64Decode(stored);
    if (key.length != keyLength) {
      throw StateError('Stored database key has the wrong length');
    }
    return key;
  }

  /// Generates, stores and returns a fresh key, and confirms it reads back
  /// before anything is encrypted with it.
  Future<Uint8List> create() async {
    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(keyLength, (_) => random.nextInt(256)),
    );
    await _secureStorage.write(key: keyStorageId, value: base64Encode(key));
    final readBack = await read();
    if (readBack == null || !_equal(readBack, key)) {
      throw StateError('Database key did not persist');
    }
    return key;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
