import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain options for every Seedling secret on iOS.
///
/// `first_unlock_this_device` keeps items readable by background work after
/// the first unlock, but — unlike the plugin default (`unlocked`) — the items
/// never leave this device: they are not restored from iCloud/iTunes backups
/// and do not migrate to a new phone. That matters because the database key
/// decrypts the local database; a backup must not carry both.
const IOSOptions seedlingIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// The single way Seedling constructs [FlutterSecureStorage]: every secret
/// is written with [seedlingIOSOptions].
FlutterSecureStorage createSeedlingSecureStorage() =>
    const FlutterSecureStorage(iOptions: seedlingIOSOptions);
