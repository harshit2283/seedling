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

/// Encrypts/decrypts cloud sync payload fields using a user passphrase key.
///
/// Key handling:
/// - The passphrase is stretched once with PBKDF2 into a master key, using a
///   random per-user salt. The salt lives in the user's own remote sync space
///   (a small [SyncKeyring] next to the synced records, created on first
///   enable together with an encrypted key-check value), and every device
///   reads it before deriving, so all devices get the same master key, a
///   wrong passphrase is caught up front, and cracking work can't be reused
///   across Seedling users.
/// - Only the master key (plus its KDF parameters) is written to secure
///   storage; the raw passphrase never is.
/// - Each sync batch picks a random record salt, and the per-record AES key is
///   HKDF(master, record salt). HKDF is cheap, so pulling many records never
///   re-runs PBKDF2 per record; derived keys are also cached per salt.
/// - Field ciphertexts are bound to their record and field name (AES-GCM
///   AAD), and the whole record, plaintext metadata included, carries an
///   HMAC-SHA256 (`syncMac`).
class SyncCryptoService {
  static const int syncEncryptionVersion = 1;
  static const _keyMaterialStorageId = 'seedling_sync_key';
  static const _saltField = 'syncEncryptionSalt';
  static const _versionField = 'syncEncryptionVersion';
  static const _macField = 'syncMac';

  static const _fieldPrefix = 'syncenc:v1:';
  static const _kdfIterations = 210000;
  static const _recordKeyInfo = 'seedling.sync.record-key.v1';
  static const _keyCheckInfo = 'seedling.sync.key-check.v1';
  static const _keyCheckPlaintext = 'seedling-key-check-v1';
  static const _recordMacInfo = 'seedling.sync.record-mac.v1';

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
  final SyncKeyring _keyring;

  /// Current master key and the keyring salt it was derived with.
  Uint8List? _masterKey;
  List<int>? _masterKdfSaltBytes;

  /// Derived per-salt record keys, keyed by base64(salt).
  final Map<String, Uint8List> _recordKeyCache = {};

  SyncCryptoService({
    required SyncKeyring keyring,
    FlutterSecureStorage? secureStorage,
    AesGcm? aesGcm,
    Pbkdf2? pbkdf2,
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
    return material != null && material.isNotEmpty;
  }

  /// Derives and stores the sync key for [passphrase].
  ///
  /// The account's random salt is read from the keyring (or created, with a
  /// key-check value) first; a passphrase that fails the key check is
  /// rejected with [SyncWrongPassphraseException] and nothing is stored.
  Future<void> setPassphrase(String passphrase) async {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw const SyncPayloadCryptoException(
        'Passphrase must be at least 8 characters.',
      );
    }
    final (master, kdfSalt) = await _keyFromKeyring(normalized);
    await _storeMasterKey(master, kdfSalt: kdfSalt);
    _recordKeyCache.clear();
    _masterKey = master;
    _masterKdfSaltBytes = kdfSalt;
  }

  /// Reads (or creates) the keyring and returns the master key and salt for
  /// [passphrase], verifying the key check when there is one.
  Future<(Uint8List, List<int>)> _keyFromKeyring(String passphrase) async {
    var remote = await _keyring.read();
    List<int> salt;
    Uint8List master;
    if (remote == null) {
      salt = _randomBytes(32);
      master = await _pbkdf2Bytes(passphrase, salt: salt);
      remote = await _keyring.publish({
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
    if (check is! String || !await _verifyKeyCheck(master, check)) {
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
  /// [keyring], and the key check verifies.
  Future<bool> matchesKeyring(Map<String, dynamic> keyring) async {
    final salt = keyring['kdfSalt'];
    final check = keyring['check'];
    if (salt is! String || check is! String) return false;
    if (!await usesKdfSalt(base64Decode(salt))) return false;
    return _verifyKeyCheck(_masterKey!, check);
  }

  /// The keyring entry (`{kdfSalt, check}`) for the current key, used to
  /// restore a missing keyring. Null when there is no key.
  Future<Map<String, dynamic>?> keyringForCurrentKey() async {
    try {
      await _loadMasterKey();
    } on SyncPassphraseMissingException {
      return null;
    }
    final salt = _masterKdfSaltBytes;
    if (salt == null) return null;
    return {
      'kdfSalt': base64Encode(salt),
      'check': await _keyCheck(_masterKey!),
    };
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
    return salt == null ? null : base64Encode(salt);
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
    final keyBytes = await _recordKeyFromMaster(await _loadMasterKey(), salt);
    return SyncEncryptionSession._(salt: salt, keyBytes: keyBytes);
  }

  Future<Map<String, dynamic>> encryptRecordFields(
    Map<String, dynamic> record, {
    SyncEncryptionSession? session,
  }) async {
    final activeSession = session ?? await createEncryptionSession();
    final output = Map<String, dynamic>.from(record)
      ..remove(_macField)
      ..[_versionField] = syncEncryptionVersion
      ..[_saltField] = base64Encode(activeSession.salt);
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
    'seedling-record|${record['syncUUID']}|$field|$syncEncryptionVersion',
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
    final version = output[_versionField];
    if (version != syncEncryptionVersion) {
      throw SyncPayloadCryptoException(
        'Unsupported sync encryption version: $version',
      );
    }
    final keyBytes = await _recordKeyFromMaster(
      await _loadMasterKey(),
      _readRecordSalt(output),
    );
    final mac = output[_macField];
    final expected = await _recordMac(output, keyBytes);
    if (mac is! String ||
        !_sameBytes(utf8.encode(mac), utf8.encode(expected))) {
      throw const SyncPayloadCryptoException(
        'Sync record failed authentication.',
      );
    }
    for (final field in _encryptedFields) {
      final value = output[field];
      if (value is String && value.isNotEmpty) {
        output[field] = await _decryptValue(
          value,
          keyBytes,
          aad: _fieldAad(output, field),
        );
      }
    }
    output.remove(_macField);
    return output;
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
    List<int> salt,
  ) async {
    final cacheKey = base64Encode(salt);
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

  /// Returns the stored master key.
  Future<Uint8List> _loadMasterKey() async {
    final cached = _masterKey;
    if (cached != null) return cached;
    final material = await _secureStorage.read(key: _keyMaterialStorageId);
    if (material == null || material.isEmpty) {
      throw const SyncPassphraseMissingException();
    }
    try {
      final decoded = jsonDecode(material) as Map<String, dynamic>;
      final key = base64Decode(decoded['key'] as String);
      if (decoded['v'] != 1 || key.length != 32) {
        throw const FormatException('bad key material');
      }
      _masterKdfSaltBytes = base64Decode(decoded['salt'] as String);
      return _masterKey = Uint8List.fromList(key);
    } catch (_) {
      throw const SyncPassphraseMissingException();
    }
  }

  Future<void> _storeMasterKey(Uint8List master, {required List<int> kdfSalt}) {
    return _secureStorage.write(
      key: _keyMaterialStorageId,
      value: jsonEncode({
        'v': 1,
        'kdf': 'pbkdf2-sha256',
        'iterations': _kdfIterations,
        'salt': base64Encode(kdfSalt),
        'key': base64Encode(master),
      }),
    );
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

  const SyncEncryptionSession._({
    required Uint8List salt,
    required Uint8List keyBytes,
  }) : _salt = salt,
       _keyBytes = keyBytes;

  Uint8List get salt => Uint8List.fromList(_salt);
  Uint8List get keyBytes => Uint8List.fromList(_keyBytes);
}
