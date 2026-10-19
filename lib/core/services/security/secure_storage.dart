import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/sync_crypto_service.dart';
import 'at_rest_encryption_service.dart';
import 'clock_guard_service.dart';

/// Keychain options for every Seedling secret on iOS.
///
/// `first_unlock_this_device` keeps items readable by background work after
/// the first unlock, but — unlike the plugin default (`unlocked`) — the items
/// never leave this device: they are not restored from iCloud/iTunes backups
/// and do not migrate to a new phone. That matters because the at-rest key
/// decrypts the local database; a backup must not carry both.
const IOSOptions seedlingIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// The single way Seedling constructs [FlutterSecureStorage].
FlutterSecureStorage createSeedlingSecureStorage() =>
    const FlutterSecureStorage(iOptions: seedlingIOSOptions);

/// Re-writes secrets created before [seedlingIOSOptions] existed so they pick
/// up the device-only keychain accessibility.
///
/// iOS cannot change kSecAttrAccessible in place; flutter_secure_storage's
/// write deletes the old item and re-adds it when the accessibility differs,
/// and reads ignore accessibility, so "read old, write new" migrates safely.
class SecureStorageAccessibilityMigration {
  /// Marker written (with the new accessibility) once migration completes.
  @visibleForTesting
  static const markerKey = 'seedling_keychain_accessibility_v2';

  /// Every secure-storage key Seedling has ever written.
  static const List<String> knownKeys = [
    AtRestEncryptionService.keyStorageId,
    ClockGuardService.storageKey,
    ...SyncCryptoService.secureStorageKeys,
  ];

  final FlutterSecureStorage _storage;

  SecureStorageAccessibilityMigration({FlutterSecureStorage? storage})
    : _storage = storage ?? createSeedlingSecureStorage();

  /// Runs once per install; safe to call on every launch. Never throws.
  Future<void> run() async {
    try {
      if (await _storage.read(key: markerKey, iOptions: seedlingIOSOptions) !=
          null) {
        return;
      }
      for (final key in knownKeys) {
        final value = await _storage.read(
          key: key,
          iOptions: seedlingIOSOptions,
        );
        if (value == null) continue;
        await _storage.write(
          key: key,
          value: value,
          iOptions: seedlingIOSOptions,
        );
      }
      await _storage.write(
        key: markerKey,
        value: '1',
        iOptions: seedlingIOSOptions,
      );
    } catch (_) {
      // Best effort: secrets stay readable under the old accessibility and
      // the migration retries next launch because the marker wasn't written.
    }
  }
}
