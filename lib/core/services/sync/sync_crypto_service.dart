import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/secure_storage.dart';

/// Base class for sync payload encryption/decryption failures.
abstract class SyncCryptoException implements Exception {
  final String message;

  const SyncCryptoException(this.message);

  @override
  String toString() => message;
}

/// Thrown when sync encryption is required but no passphrase-derived key exists.
class SyncPassphraseMissingException extends SyncCryptoException {
  const SyncPassphraseMissingException([
    super.message = _missingPassphraseText,
  ]);
}

/// Thrown when encrypted sync payloads cannot be processed safely.
class SyncPayloadCryptoException extends SyncCryptoException {
  const SyncPayloadCryptoException(super.message);
}

/// Thrown for a remote record that carries no encryption envelope.
///
/// Every record this app has ever pushed is encrypted and versioned, so an
/// unversioned record is either foreign or tampered with. Its "plaintext"
/// fields must never be imported (they could be anything, including another
/// record's ciphertext). Sync skips such records rather than failing.
class SyncUnversionedRecordException extends SyncPayloadCryptoException {
  const SyncUnversionedRecordException()
    : super('Sync record has no encryption version; ignored.');
}

/// Thrown when the remote sync space's key salt differs from the one this
/// device's key was derived with (e.g. two devices enabled sync at the same
/// moment). Re-entering the passphrase re-derives the key with the shared
/// salt.
class SyncKeySaltMismatchException extends SyncPassphraseMissingException {
  const SyncKeySaltMismatchException()
    : super(
        'Your sync key needs refreshing. Re-enter your sync passphrase in '
        'Settings > Privacy > Sync passphrase.',
      );
}

/// Thrown when the passphrase doesn't match the account's key-check value:
/// the key it produces could not read anything other devices sync.
class SyncWrongPassphraseException extends SyncPayloadCryptoException {
  const SyncWrongPassphraseException()
    : super(
        'That passphrase doesn\'t match the one your other devices use. '
        'Check it and try again.',
      );
}

/// The account keyring in the user's own sync space:
/// `{kdfSalt: base64 random salt, check: encrypted key-check value}`.
abstract class SyncKeyring {
  /// The keyring every device uses, or null if none exists yet.
  Future<Map<String, dynamic>?> read();

  /// Publishes [keyring] unless one exists; returns the keyring in effect.
  Future<Map<String, dynamic>> publish(Map<String, dynamic> keyring);
}

const _missingPassphraseText =
    'Sync passphrase is not set. Add it in Settings > Privacy > Sync passphrase.';

/// Thrown when an older (v2) sync record needs the passphrase itself, which is
/// no longer kept at rest. Re-entering the passphrase unlocks it for the
/// current app session.
class SyncPassphraseReentryRequiredException
    extends SyncPassphraseMissingException {
  const SyncPassphraseReentryRequiredException()
    : super(
        'Some older synced memories need your sync passphrase again. '
        'Re-enter it in Settings > Privacy > Sync passphrase.',
      );
}

/// Encrypts/decrypts cloud sync payload fields using a user passphrase key.
///
/// Key handling (v3):
/// - The passphrase is stretched once with PBKDF2 into a master key. Only the
///   master key (plus its KDF parameters) is written to secure storage; the
///   raw passphrase never is.
/// - Each sync batch picks a random record salt, and the per-record AES key is
///   HKDF(master, record salt). HKDF is cheap, so pulling many records no
///   longer re-runs PBKDF2 per record; derived keys are also cached per salt.
/// - v4: the PBKDF2 salt is random per user. It lives in the user's own
///   remote sync space (a small [SyncKeyring] next to the synced records,
///   created on first enable together with an encrypted key-check value) and
///   every device reads it before deriving, so all devices get the same
///   master key, a wrong passphrase is caught up front, and cracking work
///   can't be reused across Seedling users.
/// - v3 (pre-release only): the salt was a fixed app-wide value. Keys stored
///   that way keep working; the next [setPassphrase] moves to v4 and keeps
///   the v3 key alongside so v3 records stay readable.
///
/// Migration from v2 (raw passphrase at rest): on first use the stored
/// passphrase is stretched into the v3 master key, the raw passphrase is
/// deleted from storage, and it is kept in memory only for this app session
/// so v2 records (whose keys were PBKDF2(passphrase, record salt)) can still
/// be read. v2 records arriving in a later session need the passphrase
/// re-entered ([SyncPassphraseReentryRequiredException]).
class SyncCryptoService {
  static const int syncEncryptionVersion = 4;
  static const int _fixedSaltVersion = 3;
  static const int _legacyPassphraseVersion = 2;
  static const _legacyPassphraseStorageId = 'seedling_sync_passphrase_v2';
  static const _keyMaterialStorageId = 'seedling_sync_key_v3';
  static const _saltField = 'syncEncryptionSalt';

  /// Every secure-storage key this service reads or writes.
  static const secureStorageKeys = <String>[
    _legacyPassphraseStorageId,
    _keyMaterialStorageId,
  ];
  static const _fieldPrefix = 'syncenc:v1:';
  static const _kdfIterations = 210000;
  static const _masterKdfSalt = 'seedling.sync.master-kdf.v3';
  static const _recordKeyInfo = 'seedling.sync.record-key.v3';
  static const _keyCheckInfo = 'seedling.sync.key-check.v1';
  static const _keyCheckPlaintext = 'seedling-key-check-v1';
  static const _recordMacInfo = 'seedling.sync.record-mac.v1';

  /// Record layout written by this build: field ciphertexts are bound to
  /// their record and field name (AES-GCM AAD) and the whole record,
  /// plaintext metadata included, carries an HMAC-SHA256 (`syncMac`).
  /// Records without it (older builds) are still read.
  static const int recordFormat = 2;
  static const _formatField = 'syncRecordFormat';
  static const _macField = 'syncMac';

  static const _encryptedFields = <String>[
    'text',
    'title',
    'context',
    'mood',
    'tags',
    'transcription',
    'detectedTheme',
    'manualLinkIds',
    // Per-file key for the encrypted media blob (see SyncMediaCrypto).
    'mediaKey',
  ];

  final FlutterSecureStorage _secureStorage;
  final AesGcm _aesGcm;
  final Pbkdf2 _pbkdf2;
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Hmac _hmac = Hmac.sha256();
  final SyncKeyring? _keyring;

  /// Current master key and the record version it encrypts as (4 with a
  /// per-user salt; 3 for a pre-release fixed-salt key).
  Uint8List? _masterKey;
  int _masterVersion = syncEncryptionVersion;
  List<int>? _masterKdfSaltBytes;

  /// Fixed-salt (v3) key kept after moving to v4, to read v3 records.
  Uint8List? _fixedSaltKey;

  /// Raw passphrase, memory-only, used solely to read legacy v2 records.
  String? _sessionPassphrase;

  /// Derived per-salt record keys, keyed by `version:base64(salt)`.
  final Map<String, Uint8List> _recordKeyCache = {};

  SyncCryptoService({
    FlutterSecureStorage? secureStorage,
    AesGcm? aesGcm,
    Pbkdf2? pbkdf2,
    SyncKeyring? keyring,
  }) : _keyring = keyring,
       _secureStorage = secureStorage ?? createSeedlingSecureStorage(),
       _aesGcm = aesGcm ?? AesGcm.with256bits(),
       _pbkdf2 =
           pbkdf2 ??
           Pbkdf2(
             macAlgorithm: Hmac.sha256(),
             iterations: _kdfIterations,
             bits: 256,
           );

  Future<bool> hasPassphrase() async {
    if (_masterKey != null) return true;
    final material = await _secureStorage.read(key: _keyMaterialStorageId);
    if (material != null && material.isNotEmpty) return true;
    final legacy = await _secureStorage.read(key: _legacyPassphraseStorageId);
    return legacy != null && legacy.isNotEmpty;
  }

  /// Derives and stores the sync key for [passphrase].
  ///
  /// With a keyring, the account's random salt is read (or created, with a
  /// key-check value) first; a passphrase that fails the key check is
  /// rejected with [SyncWrongPassphraseException] and nothing is stored.
  /// The fixed-salt (v3, pre-release) key is always derived too, so even a
  /// brand-new device can read v3 records.
  Future<void> setPassphrase(String passphrase) async {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw const SyncPayloadCryptoException(
        'Passphrase must be at least 8 characters.',
      );
    }
    final fixedSaltKey = await _pbkdf2Bytes(
      normalized,
      salt: utf8.encode(_masterKdfSalt),
    );
    final Uint8List master;
    final List<int> kdfSalt;
    final int version;
    if (_keyring == null) {
      // No remote keyring available (tests, tooling): app-wide salt.
      master = fixedSaltKey;
      kdfSalt = utf8.encode(_masterKdfSalt);
      version = _fixedSaltVersion;
    } else {
      (master, kdfSalt) = await _keyFromKeyring(normalized, _keyring);
      version = syncEncryptionVersion;
    }
    await _storeMasterKey(
      master,
      version: version,
      kdfSalt: kdfSalt,
      fixedSaltKey: version == _fixedSaltVersion ? null : fixedSaltKey,
    );
    await _secureStorage.write(key: _legacyPassphraseStorageId, value: null);
    _recordKeyCache.clear();
    _masterKey = master;
    _masterVersion = version;
    _masterKdfSaltBytes = kdfSalt;
    _fixedSaltKey = fixedSaltKey;
    _sessionPassphrase = normalized;
  }

  /// Reads (or creates) the keyring and returns the master key and salt for
  /// [passphrase], verifying the key check when there is one.
  Future<(Uint8List, List<int>)> _keyFromKeyring(
    String passphrase,
    SyncKeyring keyring,
  ) async {
    var remote = await keyring.read();
    List<int> salt;
    Uint8List master;
    if (remote == null) {
      salt = _randomBytes(32);
      master = await _pbkdf2Bytes(passphrase, salt: salt);
      remote = await keyring.publish({
        'kdfSalt': base64Encode(salt),
        'check': await _keyCheck(master),
      });
      final winner = base64Decode(remote['kdfSalt'] as String);
      if (!_sameBytes(winner, salt)) {
        // Another device published first; use its salt.
        salt = winner;
        master = await _pbkdf2Bytes(passphrase, salt: salt);
      }
    } else {
      salt = base64Decode(remote['kdfSalt'] as String);
      master = await _pbkdf2Bytes(passphrase, salt: salt);
    }
    final check = remote['check'];
    if (check is String && !await _verifyKeyCheck(master, check)) {
      throw const SyncWrongPassphraseException();
    }
    return (master, salt);
  }

  Future<Uint8List> _keyCheckKey(Uint8List master) async {
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(master),
      nonce: utf8.encode('seedling.key-check'),
      info: utf8.encode(_keyCheckInfo),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  Future<String> _keyCheck(Uint8List master) async =>
      _encryptValue(_keyCheckPlaintext, await _keyCheckKey(master));

  Future<bool> _verifyKeyCheck(Uint8List master, String check) async {
    try {
      return await _decryptValue(check, await _keyCheckKey(master)) ==
          _keyCheckPlaintext;
    } on SyncPayloadCryptoException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// Whether this device's key is the account's key: same salt as
  /// [keyring], and (when the keyring carries one) the key check verifies.
  Future<bool> matchesKeyring(Map<String, dynamic> keyring) async {
    final salt = keyring['kdfSalt'];
    if (salt is! String) return false;
    if (!await usesKdfSalt(base64Decode(salt))) return false;
    final check = keyring['check'];
    if (check is! String) return true;
    return _verifyKeyCheck(_masterKey!, check);
  }

  /// Identifies the current key (not secret): changes whenever the key is
  /// re-derived with a different salt. Null when no key is set up.
  Future<String?> keyFingerprint() async {
    try {
      await _loadMasterKey();
    } on SyncPassphraseMissingException {
      return null;
    }
    final salt = _masterKdfSaltBytes;
    return '$_masterVersion:${salt == null ? '' : base64Encode(salt)}';
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Whether this device's key was derived with [kdfSalt] (the salt in the
  /// remote keyring). False when no key is set up.
  Future<bool> usesKdfSalt(List<int> kdfSalt) async {
    try {
      await _loadMasterKey();
    } on SyncPassphraseMissingException {
      return false;
    }
    final own = _masterKdfSaltBytes;
    return own != null && _sameBytes(own, kdfSalt);
  }

  Future<SyncEncryptionSession> createEncryptionSession() async {
    final salt = _randomBytes(16);
    final master = await _loadMasterKey();
    final keyBytes = await _recordKeyFromMaster(
      master,
      salt,
      version: _masterVersion,
    );
    return SyncEncryptionSession._(
      salt: salt,
      keyBytes: keyBytes,
      version: _masterVersion,
    );
  }

  Future<Map<String, dynamic>> encryptRecordFields(
    Map<String, dynamic> record, {
    SyncEncryptionSession? session,
  }) async {
    final activeSession = session ?? await createEncryptionSession();
    final output = Map<String, dynamic>.from(record)
      ..remove(_macField)
      ..['syncEncryptionVersion'] = activeSession.version
      ..[_saltField] = base64Encode(activeSession.salt)
      ..[_formatField] = recordFormat;
    for (final field in _encryptedFields) {
      final value = output[field];
      if (value is String && value.isNotEmpty) {
        output[field] = await _encryptValue(
          value,
          activeSession.keyBytes,
          aad: _fieldAad(output, field),
        );
      }
    }
    output[_macField] = await _recordMac(output, activeSession.keyBytes);
    return output;
  }

  /// Binds a field's ciphertext to its record and field name, so it can't be
  /// moved to another record or field.
  List<int> _fieldAad(Map<String, dynamic> record, String field) => utf8.encode(
    'seedling-record|${record['syncUUID']}|$field|'
    '${record['syncEncryptionVersion']}|$recordFormat',
  );

  /// HMAC-SHA256 over every key/value of the record except the MAC itself,
  /// in sorted key order. Covers the plaintext metadata (isDeleted,
  /// modifiedAt, capsuleUnlockDate, mediaAssetId, typeIndex, ...).
  Future<String> _recordMac(
    Map<String, dynamic> record,
    Uint8List recordKey,
  ) async {
    final keys = record.keys.where((k) => k != _macField).toList()..sort();
    final canonical = jsonEncode([
      for (final k in keys) [k, record[k]],
    ]);
    final macKey = await _hkdf.deriveKey(
      secretKey: SecretKey(recordKey),
      nonce: utf8.encode('seedling.record-mac'),
      info: utf8.encode(_recordMacInfo),
    );
    final mac = await _hmac.calculateMac(
      utf8.encode(canonical),
      secretKey: macKey,
    );
    return base64Encode(mac.bytes);
  }

  Future<Map<String, dynamic>> decryptRecordFields(
    Map<String, dynamic> record,
  ) async {
    final output = Map<String, dynamic>.from(record);
    final version = output['syncEncryptionVersion'];
    if (version == null) {
      throw const SyncUnversionedRecordException();
    }
    final keyBytes = await _resolveKeyBytesForVersion(output, version);
    final authenticated = output[_formatField] == recordFormat;
    if (authenticated) {
      final mac = output[_macField];
      final expected = await _recordMac(output, keyBytes);
      if (mac is! String ||
          !_sameBytes(utf8.encode(mac), utf8.encode(expected))) {
        throw const SyncPayloadCryptoException(
          'Sync record failed authentication.',
        );
      }
    } else if (output.containsKey(_formatField)) {
      throw SyncPayloadCryptoException(
        'Unsupported sync record format: ${output[_formatField]}',
      );
    }
    for (final field in _encryptedFields) {
      final value = output[field];
      if (value is String && value.isNotEmpty) {
        output[field] = await _decryptValue(
          value,
          keyBytes,
          aad: authenticated ? _fieldAad(output, field) : const [],
        );
      }
    }
    output
      ..remove(_macField)
      ..remove(_formatField);
    return output;
  }

  Future<Uint8List> _resolveKeyBytesForVersion(
    Map<String, dynamic> record,
    Object version,
  ) async {
    if (version != syncEncryptionVersion &&
        version != _fixedSaltVersion &&
        version != _legacyPassphraseVersion) {
      throw SyncPayloadCryptoException(
        'Unsupported sync encryption version: $version',
      );
    }
    final saltBytes = _readRecordSalt(record);
    if (version == _legacyPassphraseVersion) {
      return _recordKeyLegacyV2(saltBytes);
    }
    final master = await _loadMasterKey();
    if (version == _masterVersion) {
      return _recordKeyFromMaster(master, saltBytes, version: _masterVersion);
    }
    if (version == _fixedSaltVersion) {
      final fixed = _fixedSaltKey;
      if (fixed == null) throw const SyncPassphraseReentryRequiredException();
      return _recordKeyFromMaster(fixed, saltBytes, version: _fixedSaltVersion);
    }
    // A v4 record while this device still has a pre-release v3 key: the
    // passphrase must be re-entered to derive the per-user-salt key.
    throw const SyncKeySaltMismatchException();
  }

  Uint8List _readRecordSalt(Map<String, dynamic> record) {
    final encodedSalt = record[_saltField] as String?;
    if (encodedSalt == null || encodedSalt.isEmpty) {
      throw const SyncPayloadCryptoException(
        'Encrypted sync record is missing its salt.',
      );
    }
    try {
      return Uint8List.fromList(base64Decode(encodedSalt));
    } on FormatException {
      throw const SyncPayloadCryptoException(
        'Encrypted sync record has malformed salt.',
      );
    }
  }

  Future<Uint8List> _recordKeyFromMaster(
    Uint8List master,
    List<int> salt, {
    required int version,
  }) async {
    final cacheKey = '$version:${base64Encode(salt)}';
    final cached = _recordKeyCache[cacheKey];
    if (cached != null) return cached;
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(master),
      nonce: salt,
      info: utf8.encode(_recordKeyInfo),
    );
    final bytes = Uint8List.fromList(await derived.extractBytes());
    _recordKeyCache[cacheKey] = bytes;
    return bytes;
  }

  Future<Uint8List> _recordKeyLegacyV2(List<int> salt) async {
    final cacheKey = '$_legacyPassphraseVersion:${base64Encode(salt)}';
    final cached = _recordKeyCache[cacheKey];
    if (cached != null) return cached;
    // Loading the master key migrates a stored legacy passphrase into memory.
    await _loadMasterKey();
    final passphrase = _sessionPassphrase;
    if (passphrase == null) {
      throw const SyncPassphraseReentryRequiredException();
    }
    final bytes = await _pbkdf2Bytes(passphrase, salt: salt);
    _recordKeyCache[cacheKey] = bytes;
    return bytes;
  }

  /// Returns the v3 master key, migrating a legacy stored passphrase once.
  Future<Uint8List> _loadMasterKey() async {
    final cached = _masterKey;
    if (cached != null) return cached;

    final material = await _secureStorage.read(key: _keyMaterialStorageId);
    if (material != null && material.isNotEmpty) {
      final master = _parseKeyMaterial(material);
      _masterKey = master;
      return master;
    }
    // Migration from v2 (raw passphrase at rest) below.

    final legacy = await _secureStorage.read(key: _legacyPassphraseStorageId);
    if (legacy == null || legacy.isEmpty) {
      throw const SyncPassphraseMissingException();
    }
    final keyring = _keyring;
    final Uint8List master;
    final List<int> kdfSalt;
    final int version;
    if (keyring != null) {
      (master, kdfSalt) = await _keyFromKeyring(legacy, keyring);
      version = syncEncryptionVersion;
    } else {
      kdfSalt = utf8.encode(_masterKdfSalt);
      master = await _pbkdf2Bytes(legacy, salt: kdfSalt);
      version = _fixedSaltVersion;
    }
    await _storeMasterKey(master, version: version, kdfSalt: kdfSalt);
    await _secureStorage.write(key: _legacyPassphraseStorageId, value: null);
    _masterKey = master;
    _masterVersion = version;
    _masterKdfSaltBytes = kdfSalt;
    _sessionPassphrase = legacy;
    return master;
  }

  Future<void> _storeMasterKey(
    Uint8List master, {
    required int version,
    required List<int> kdfSalt,
    Uint8List? fixedSaltKey,
  }) {
    return _secureStorage.write(
      key: _keyMaterialStorageId,
      value: jsonEncode({
        'v': version,
        'kdf': 'pbkdf2-sha256',
        'iterations': _kdfIterations,
        'salt': base64Encode(kdfSalt),
        'key': base64Encode(master),
        if (fixedSaltKey != null) 'v3Key': base64Encode(fixedSaltKey),
      }),
    );
  }

  /// Parses stored key material, setting the master's version, KDF salt and
  /// any kept fixed-salt key. Pre-release material without a 'v' is v3.
  Uint8List _parseKeyMaterial(String material) {
    try {
      final decoded = jsonDecode(material) as Map<String, dynamic>;
      final key = base64Decode(decoded['key'] as String);
      if (key.length != 32) throw const FormatException('bad key length');
      final version = (decoded['v'] as num?)?.toInt() ?? _fixedSaltVersion;
      final salt = decoded['salt'] as String?;
      final v3Key = decoded['v3Key'] as String?;
      _masterVersion = version == syncEncryptionVersion
          ? syncEncryptionVersion
          : _fixedSaltVersion;
      _masterKdfSaltBytes = salt == null ? null : base64Decode(salt);
      _fixedSaltKey = _masterVersion == _fixedSaltVersion
          ? Uint8List.fromList(key)
          : (v3Key == null ? null : Uint8List.fromList(base64Decode(v3Key)));
      return Uint8List.fromList(key);
    } catch (_) {
      throw const SyncPassphraseMissingException();
    }
  }

  Future<String> _encryptValue(
    String value,
    Uint8List keyBytes, {
    List<int> aad = const [],
  }) async {
    final nonce = _randomBytes(12);
    final secretBox = await _aesGcm.encrypt(
      Uint8List.fromList(utf8.encode(value)),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
      aad: aad,
    );
    return '$_fieldPrefix${base64Encode(nonce)}:${base64Encode(secretBox.cipherText)}:${base64Encode(secretBox.mac.bytes)}';
  }

  Future<String> _decryptValue(
    String value,
    Uint8List keyBytes, {
    List<int> aad = const [],
  }) async {
    if (!value.startsWith(_fieldPrefix)) {
      throw const SyncPayloadCryptoException(
        'Encrypted sync record field is malformed.',
      );
    }

    final payload = value.substring(_fieldPrefix.length);
    final parts = payload.split(':');
    if (parts.length != 3) {
      throw const SyncPayloadCryptoException(
        'Encrypted sync record field is malformed.',
      );
    }

    final nonce = base64Decode(parts[0]);
    final ciphertext = base64Decode(parts[1]);
    final mac = base64Decode(parts[2]);

    try {
      final clearBytes = await _aesGcm.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(keyBytes),
        aad: aad,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const SyncPayloadCryptoException(
        'Failed to decrypt sync payload. Verify your sync passphrase.',
      );
    }
  }

  Future<Uint8List> _pbkdf2Bytes(
    String passphrase, {
    required List<int> salt,
  }) async {
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class SyncEncryptionSession {
  final Uint8List _salt;
  final Uint8List _keyBytes;

  /// The record encryption version this session's key belongs to.
  final int version;

  const SyncEncryptionSession._({
    required Uint8List salt,
    required Uint8List keyBytes,
    required this.version,
  }) : _salt = salt,
       _keyBytes = keyBytes;

  Uint8List get salt => Uint8List.fromList(_salt);
  Uint8List get keyBytes => Uint8List.fromList(_keyBytes);
}
