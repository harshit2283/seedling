import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'sync_crypto_service.dart';

/// Thrown when an encrypted media blob is malformed, truncated, tampered
/// with, or encrypted under a different key.
class SyncMediaCryptoException extends SyncPayloadCryptoException {
  const SyncMediaCryptoException(super.message);
}

/// End-to-end encryption for synced photos, voice memos and object photos.
///
/// Keys: every uploaded file gets its own fresh random 256-bit key. That key
/// travels only inside the synced record's `mediaKey` field, which is
/// encrypted like the memory text (AES-256-GCM under
/// HKDF(master key, record salt), where the master key is PBKDF2 of the
/// passphrase with the account's own random salt). So the blob is only
/// readable with the passphrase, and a leaked file key exposes one file.
///
/// Format (streamed in fixed chunks, so a 50 MB file never needs a 50 MB
/// buffer):
///
///     header  = "SDM1" | chunkSize (u32 BE) | noncePrefix (8 random bytes)
///     chunk i = AES-256-GCM(key, nonce = noncePrefix | i (u32 BE),
///                           aad = header | i (u32 BE) | isLast (1 byte))
///               -> ciphertext (<= chunkSize bytes) | 16-byte tag
///
/// The last chunk (possibly empty) is sealed with isLast = 1, so dropping,
/// reordering or appending chunks fails authentication, as does any bit flip
/// or a wrong key. Nonces never repeat: each file has its own key.
class SyncMediaCrypto {
  static const _magic = [0x53, 0x44, 0x4D, 0x31]; // "SDM1"
  static const headerLength = 16;
  static const tagLength = 16;
  static const defaultChunkSize = 64 * 1024;

  /// Files larger than this are not synced (bounded work on phones).
  static const maxPlaintextBytes = 50 * 1024 * 1024;

  final AesGcm _aes = AesGcm.with256bits();
  final int chunkSize;

  SyncMediaCrypto({this.chunkSize = defaultChunkSize});

  /// A fresh random per-file key.
  Uint8List newFileKey() => _randomBytes(32);

  /// Encrypts [input] into [output] (overwritten).
  Future<void> encryptFile(File input, File output, List<int> key) async {
    _checkKey(key);
    final header = Uint8List(headerLength)
      ..setRange(0, 4, _magic)
      ..buffer.asByteData().setUint32(4, chunkSize)
      ..setRange(8, 16, _randomBytes(8));
    final secretKey = SecretKey(key);
    final reader = await input.open();
    final writer = await output.open(mode: FileMode.write);
    try {
      await writer.writeFrom(header);
      final total = await reader.length();
      var offset = 0;
      var index = 0;
      do {
        final remaining = total - offset;
        final take = remaining < chunkSize ? remaining : chunkSize;
        final plain = await reader.read(take);
        offset += plain.length;
        final isLast = offset >= total;
        final box = await _aes.encrypt(
          plain,
          secretKey: secretKey,
          nonce: _nonce(header, index),
          aad: _aad(header, index, isLast),
        );
        await writer.writeFrom(box.cipherText);
        await writer.writeFrom(box.mac.bytes);
        index++;
        if (isLast) break;
      } while (true);
    } finally {
      await reader.close();
      await writer.close();
    }
  }

  /// Decrypts [input] into [output]. On any failure [output] is deleted and
  /// a [SyncMediaCryptoException] is thrown, so a half-written or forged
  /// file never lands in the media folder.
  Future<void> decryptFile(File input, File output, List<int> key) async {
    _checkKey(key);
    final secretKey = SecretKey(key);
    final reader = await input.open();
    final writer = await output.open(mode: FileMode.write);
    var ok = false;
    try {
      final total = await reader.length();
      final header = await reader.read(headerLength);
      if (header.length != headerLength ||
          !_startsWithMagic(header) ||
          total < headerLength + tagLength) {
        throw const SyncMediaCryptoException('Not an encrypted media file.');
      }
      final size = header.buffer.asByteData().getUint32(4);
      if (size == 0 || size > 16 * 1024 * 1024) {
        throw const SyncMediaCryptoException('Bad media chunk size.');
      }
      var offset = headerLength;
      var index = 0;
      while (offset < total) {
        final remaining = total - offset;
        final take = remaining < size + tagLength
            ? remaining
            : size + tagLength;
        if (take < tagLength) {
          throw const SyncMediaCryptoException('Truncated media file.');
        }
        final sealed = await reader.read(take);
        offset += sealed.length;
        final isLast = offset >= total;
        final cut = sealed.length - tagLength;
        try {
          final plain = await _aes.decrypt(
            SecretBox(
              sealed.sublist(0, cut),
              nonce: _nonce(header, index),
              mac: Mac(sealed.sublist(cut)),
            ),
            secretKey: secretKey,
            aad: _aad(header, index, isLast),
          );
          await writer.writeFrom(plain);
        } on SecretBoxAuthenticationError {
          throw const SyncMediaCryptoException(
            'Media file failed verification (tampered, truncated, or a '
            'different key).',
          );
        }
        index++;
      }
      ok = true;
    } finally {
      await reader.close();
      await writer.close();
      if (!ok && await output.exists()) await output.delete();
    }
  }

  static void _checkKey(List<int> key) {
    if (key.length != 32) {
      throw const SyncMediaCryptoException('Media key must be 32 bytes.');
    }
  }

  static bool _startsWithMagic(List<int> header) {
    for (var i = 0; i < _magic.length; i++) {
      if (header[i] != _magic[i]) return false;
    }
    return true;
  }

  static List<int> _nonce(List<int> header, int index) {
    final nonce = Uint8List(12)..setRange(0, 8, header.sublist(8, 16));
    nonce.buffer.asByteData().setUint32(8, index);
    return nonce;
  }

  static List<int> _aad(List<int> header, int index, bool isLast) {
    final aad = Uint8List(headerLength + 5)..setRange(0, headerLength, header);
    aad.buffer.asByteData().setUint32(headerLength, index);
    aad[headerLength + 4] = isLast ? 1 : 0;
    return aad;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
