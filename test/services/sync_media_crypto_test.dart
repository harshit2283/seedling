import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/sync_media_crypto.dart';

void main() {
  late Directory dir;
  // Small chunks so multi-chunk paths are exercised quickly.
  final crypto = SyncMediaCrypto(chunkSize: 1024);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('media_crypto');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<File> plainFile(int length, {int seed = 1}) async {
    final random = Random(seed);
    final bytes = Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
    return File('${dir.path}/plain_$length')..writeAsBytesSync(bytes);
  }

  test('round trips files of every chunk shape', () async {
    for (final length in [0, 1, 1023, 1024, 1025, 3 * 1024 + 5]) {
      final plain = await plainFile(length);
      final sealed = File('${dir.path}/sealed_$length');
      final opened = File('${dir.path}/opened_$length');
      final key = crypto.newFileKey();
      await crypto.encryptFile(plain, sealed, key);
      await crypto.decryptFile(sealed, opened, key);
      expect(await opened.readAsBytes(), await plain.readAsBytes());
      // Header + one tag per chunk (at least one chunk).
      final chunks = length == 0 ? 1 : (length + 1023) ~/ 1024;
      expect(
        await sealed.length(),
        SyncMediaCrypto.headerLength + length + chunks * 16,
      );
    }
  });

  Future<(File, File, List<int>)> sealedSample() async {
    final plain = await plainFile(3000);
    final sealed = File('${dir.path}/sample.enc');
    final key = crypto.newFileKey();
    await crypto.encryptFile(plain, sealed, key);
    return (plain, sealed, key);
  }

  Future<void> expectRejected(File sealed, List<int> key) async {
    final out = File('${dir.path}/rejected');
    await expectLater(
      crypto.decryptFile(sealed, out, key),
      throwsA(isA<SyncMediaCryptoException>()),
    );
    // Nothing half-written is left behind.
    expect(out.existsSync(), isFalse);
  }

  test('a flipped bit fails verification', () async {
    final (_, sealed, key) = await sealedSample();
    final bytes = await sealed.readAsBytes();
    bytes[SyncMediaCrypto.headerLength + 1500] ^= 0x01;
    await sealed.writeAsBytes(bytes);
    await expectRejected(sealed, key);
  });

  test('a tampered header fails verification', () async {
    final (_, sealed, key) = await sealedSample();
    final bytes = await sealed.readAsBytes();
    bytes[10] ^= 0x80; // nonce prefix
    await sealed.writeAsBytes(bytes);
    await expectRejected(sealed, key);
  });

  test('dropping the last chunk (truncation) is detected', () async {
    final (_, sealed, key) = await sealedSample();
    final bytes = await sealed.readAsBytes();
    // 3000 bytes = chunks of 1024, 1024, 952: keep only the first two.
    await sealed.writeAsBytes(
      bytes.sublist(0, SyncMediaCrypto.headerLength + 2 * (1024 + 16)),
    );
    await expectRejected(sealed, key);
  });

  test('appended data is detected', () async {
    final (_, sealed, key) = await sealedSample();
    await sealed.writeAsBytes([1, 2, 3], mode: FileMode.append);
    await expectRejected(sealed, key);
  });

  test('the wrong key fails', () async {
    final (_, sealed, _) = await sealedSample();
    await expectRejected(sealed, crypto.newFileKey());
  });

  test('ciphertext does not contain the plaintext', () async {
    final plain = File('${dir.path}/text')
      ..writeAsStringSync('a very recognisable memory ' * 100);
    final sealed = File('${dir.path}/text.enc');
    await crypto.encryptFile(plain, sealed, crypto.newFileKey());
    expect(
      String.fromCharCodes(await sealed.readAsBytes()),
      isNot(contains('recognisable')),
    );
  });
}
