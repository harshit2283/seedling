import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
/// - The PBKDF2 salt is a fixed, app-specific value so every device that
///   knows the passphrase derives the same master key without needing a
///   shared salt distribution channel.
///
/// Migration from v2 (raw passphrase at rest): on first use the stored
/// passphrase is stretched into the v3 master key, the raw passphrase is
/// deleted from storage, and it is kept in memory only for this app session
/// so v2 records (whose keys were PBKDF2(passphrase, record salt)) can still
/// be read. v2 records arriving in a later session need the passphrase
/// re-entered ([SyncPassphraseReentryRequiredException]).
class SyncCryptoService {
  static const int syncEncryptionVersion = 3;
  static const int _legacyPassphraseVersion = 2;
  static const _legacyPassphraseStorageId = 'seedling_sync_passphrase_v2';
  static const _keyMaterialStorageId = 'seedling_sync_key_v3';
  static const _saltField = 'syncEncryptionSalt';
  static const _fieldPrefix = 'syncenc:v1:';
  static const _kdfIterations = 210000;
  static const _masterKdfSalt = 'seedling.sync.master-kdf.v3';
  static const _recordKeyInfo = 'seedling.sync.record-key.v3';

  static const _encryptedFields = <String>[
    'text',
    'title',
    'context',
    'mood',
    'tags',
    'transcription',
    'detectedTheme',
  ];

  final FlutterSecureStorage _secureStorage;
  final AesGcm _aesGcm;
  final Pbkdf2 _pbkdf2;
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// v3 master key, cached after the first secure-storage read.
  Uint8List? _masterKey;

  /// Raw passphrase, memory-only, used solely to read legacy v2 records.
  String? _sessionPassphrase;

  /// Derived per-salt record keys, keyed by `version:base64(salt)`.
  final Map<String, Uint8List> _recordKeyCache = {};

  SyncCryptoService({
    FlutterSecureStorage? secureStorage,
    AesGcm? aesGcm,
    Pbkdf2? pbkdf2,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
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

  Future<void> setPassphrase(String passphrase) async {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw const SyncPayloadCryptoException(
        'Passphrase must be at least 8 characters.',
      );
    }
    final master = await _deriveMasterKey(normalized);
    await _storeMasterKey(master);
    await _secureStorage.write(key: _legacyPassphraseStorageId, value: null);
    _recordKeyCache.clear();
    _masterKey = master;
    _sessionPassphrase = normalized;
  }

  Future<SyncEncryptionSession> createEncryptionSession() async {
    final salt = _randomBytes(16);
    final keyBytes = await _recordKeyV3(salt);
    return SyncEncryptionSession._(salt: salt, keyBytes: keyBytes);
  }

  Future<Map<String, dynamic>> encryptRecordFields(
    Map<String, dynamic> record, {
    SyncEncryptionSession? session,
  }) async {
    final activeSession = session ?? await createEncryptionSession();
    final output = Map<String, dynamic>.from(record);
    for (final field in _encryptedFields) {
      final value = output[field];
      if (value is String && value.isNotEmpty) {
        output[field] = await _encryptValue(value, activeSession.keyBytes);
      }
    }
    output['syncEncryptionVersion'] = syncEncryptionVersion;
    output[_saltField] = base64Encode(activeSession.salt);
    return output;
  }

  Future<Map<String, dynamic>> decryptRecordFields(
    Map<String, dynamic> record,
  ) async {
    final output = Map<String, dynamic>.from(record);
    final version = output['syncEncryptionVersion'];
    if (version == null) {
      return output;
    }
    final keyBytes = await _resolveKeyBytesForVersion(output, version);
    for (final field in _encryptedFields) {
      final value = output[field];
      if (value is String && value.isNotEmpty) {
        output[field] = await _decryptValue(value, keyBytes);
      }
    }
    return output;
  }

  Future<Uint8List> _resolveKeyBytesForVersion(
    Map<String, dynamic> record,
    Object version,
  ) async {
    if (version != syncEncryptionVersion &&
        version != _legacyPassphraseVersion) {
      throw SyncPayloadCryptoException(
        'Unsupported sync encryption version: $version',
      );
    }
    final saltBytes = _readRecordSalt(record);
    if (version == syncEncryptionVersion) {
      return _recordKeyV3(saltBytes);
    }
    return _recordKeyLegacyV2(saltBytes);
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

  Future<Uint8List> _recordKeyV3(List<int> salt) async {
    final cacheKey = '$syncEncryptionVersion:${base64Encode(salt)}';
    final cached = _recordKeyCache[cacheKey];
    if (cached != null) return cached;
    final master = await _loadMasterKey();
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

    final legacy = await _secureStorage.read(key: _legacyPassphraseStorageId);
    if (legacy == null || legacy.isEmpty) {
      throw const SyncPassphraseMissingException();
    }
    final master = await _deriveMasterKey(legacy);
    await _storeMasterKey(master);
    await _secureStorage.write(key: _legacyPassphraseStorageId, value: null);
    _masterKey = master;
    _sessionPassphrase = legacy;
    return master;
  }

  Future<Uint8List> _deriveMasterKey(String passphrase) {
    return _pbkdf2Bytes(passphrase, salt: utf8.encode(_masterKdfSalt));
  }

  Future<void> _storeMasterKey(Uint8List master) {
    return _secureStorage.write(
      key: _keyMaterialStorageId,
      value: jsonEncode({
        'v': syncEncryptionVersion,
        'kdf': 'pbkdf2-sha256',
        'iterations': _kdfIterations,
        'salt': base64Encode(utf8.encode(_masterKdfSalt)),
        'key': base64Encode(master),
      }),
    );
  }

  Uint8List _parseKeyMaterial(String material) {
    try {
      final decoded = jsonDecode(material) as Map<String, dynamic>;
      final key = base64Decode(decoded['key'] as String);
      if (key.length != 32) throw const FormatException('bad key length');
      return Uint8List.fromList(key);
    } catch (_) {
      throw const SyncPassphraseMissingException();
    }
  }

  Future<String> _encryptValue(String value, Uint8List keyBytes) async {
    final nonce = _randomBytes(12);
    final secretBox = await _aesGcm.encrypt(
      Uint8List.fromList(utf8.encode(value)),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );
    return '$_fieldPrefix${base64Encode(nonce)}:${base64Encode(secretBox.cipherText)}:${base64Encode(secretBox.mac.bytes)}';
  }

  Future<String> _decryptValue(String value, Uint8List keyBytes) async {
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
