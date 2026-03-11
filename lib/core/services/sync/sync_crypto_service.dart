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

/// Encrypts/decrypts cloud sync payload fields using a user passphrase key.
class SyncCryptoService {
  static const int syncEncryptionVersion = 2;
  static const _syncPassphraseStorageId = 'seedling_sync_passphrase_v2';
  static const _saltField = 'syncEncryptionSalt';
  static const _fieldPrefix = 'syncenc:v1:';
  static const _kdfIterations = 210000;

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
    final passphrase = await _secureStorage.read(key: _syncPassphraseStorageId);
    return passphrase != null && passphrase.isNotEmpty;
  }

  Future<void> setPassphrase(String passphrase) async {
    final normalized = passphrase.trim();
    if (normalized.length < 8) {
      throw const SyncPayloadCryptoException(
        'Passphrase must be at least 8 characters.',
      );
    }
    await _secureStorage.write(
      key: _syncPassphraseStorageId,
      value: normalized,
    );
  }

  Future<SyncEncryptionSession> createEncryptionSession() async {
    final passphrase = await _readStoredPassphrase();
    final salt = _randomBytes(16);
    final keyBytes = await _deriveKeyBytes(passphrase, salt: salt);
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
    if (version == syncEncryptionVersion) {
      final encodedSalt = record[_saltField] as String?;
      if (encodedSalt == null || encodedSalt.isEmpty) {
        throw const SyncPayloadCryptoException(
          'Encrypted sync record is missing its salt.',
        );
      }
      late final Uint8List saltBytes;
      try {
        saltBytes = Uint8List.fromList(base64Decode(encodedSalt));
      } on FormatException {
        throw const SyncPayloadCryptoException(
          'Encrypted sync record has malformed salt.',
        );
      }
      final passphrase = await _readStoredPassphrase();
      return _deriveKeyBytes(passphrase, salt: saltBytes);
    }

    throw SyncPayloadCryptoException(
      'Unsupported sync encryption version: $version',
    );
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

  Future<Uint8List> _deriveKeyBytes(
    String passphrase, {
    required List<int> salt,
  }) async {
    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  Future<String> _readStoredPassphrase() async {
    final passphrase = await _secureStorage.read(key: _syncPassphraseStorageId);
    if (passphrase == null || passphrase.isEmpty) {
      throw const SyncPassphraseMissingException();
    }
    return passphrase;
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
