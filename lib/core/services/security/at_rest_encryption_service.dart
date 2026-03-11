import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Encrypts/decrypts sensitive entry fields for local at-rest protection.
class AtRestEncryptionService {
  static const _keyStorageId = 'seedling_local_master_key_v1';
  static const _payloadPrefix = 'enc:v1:';

  final FlutterSecureStorage _secureStorage;
  late final Uint8List _masterKey;

  AtRestEncryptionService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> init() async {
    final existing = await _secureStorage.read(key: _keyStorageId);
    if (existing == null || existing.isEmpty) {
      final generated = _randomBytes(32);
      await _secureStorage.write(
        key: _keyStorageId,
        value: base64Encode(generated),
      );
      _masterKey = generated;
    } else {
      _masterKey = Uint8List.fromList(base64Decode(existing));
    }
  }

  String? encryptField(String? value) {
    if (value == null || value.isEmpty) return value;
    if (isEncryptedValue(value)) return value;
    final iv = _randomBytes(12);
    final cipherText = _processAesGcm(
      isEncrypting: true,
      iv: iv,
      input: Uint8List.fromList(utf8.encode(value)),
    );
    return '$_payloadPrefix${base64Encode(iv)}:${base64Encode(cipherText)}';
  }

  bool isEncryptedValue(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith(_payloadPrefix);
  }

  String? decryptField(String? value) {
    if (value == null || value.isEmpty) return value;
    if (!isEncryptedValue(value)) return value;

    try {
      final payload = value.substring(_payloadPrefix.length);
      final separatorIndex = payload.indexOf(':');
      if (separatorIndex <= 0) {
        developer.log(
          'Decrypt failed: encrypted payload missing separator',
          name: 'AtRestEncryptionService',
        );
        return null;
      }
      final iv = Uint8List.fromList(
        base64Decode(payload.substring(0, separatorIndex)),
      );
      final cipherText = Uint8List.fromList(
        base64Decode(payload.substring(separatorIndex + 1)),
      );

      final plainBytes = _processAesGcm(
        isEncrypting: false,
        iv: iv,
        input: cipherText,
      );
      return utf8.decode(plainBytes);
    } catch (error, stackTrace) {
      developer.log(
        'Decrypt failed for encrypted field',
        name: 'AtRestEncryptionService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Uint8List _processAesGcm({
    required bool isEncrypting,
    required Uint8List iv,
    required Uint8List input,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(_masterKey),
      128,
      iv,
      Uint8List(0),
    );
    cipher.init(isEncrypting, params);
    return cipher.process(input);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
