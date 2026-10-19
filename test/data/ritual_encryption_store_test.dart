// Runs against a real ObjectBox store. Needs the native library
// (libobjectbox.so / .dylib) on the loader path; skipped otherwise.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/ritual.dart';

Future<ObjectBoxDatabase?> _tryOpen(Directory dir) async {
  try {
    return await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
  } on ArgumentError catch (e) {
    if ('$e'.contains('dynamic library')) return null;
    rethrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  ObjectBoxDatabase? db;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('obx_ritual_test');
    db = await _tryOpen(dir);
  });

  tearDown(() async {
    db?.close();
    await dir.delete(recursive: true);
  });

  test('ritual name and signature are encrypted at rest', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final ritual = Ritual(
      name: 'Coffee with Dad at the hospital',
      signature: 'coffee|dad|hospital@morning',
    );
    await store.saveRitual(ritual);

    // Caller's object and reads stay plaintext.
    expect(ritual.name, 'Coffee with Dad at the hospital');
    final read = store.getRitual(ritual.id)!;
    expect(read.name, 'Coffee with Dad at the hospital');
    expect(read.signature, 'coffee|dad|hospital@morning');
    expect(store.getAllRituals().single.name, read.name);
    expect((await store.watchRituals().first).single.name, read.name);

    // Stored form is ciphertext.
    final raw = store.ritualBoxForTesting.get(ritual.id)!;
    expect(raw.name, startsWith('enc:v1:'));
    expect(raw.signature, startsWith('enc:v1:'));
    expect(raw.name.contains('Dad'), isFalse);
  });

  test(
    'legacy plaintext rituals still read and are encrypted on open',
    () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      // Simulate a ritual written by a build without ritual encryption.
      final id = store.ritualBoxForTesting.put(
        Ritual(name: 'Sunday pancakes', signature: 'pancakes@sunday'),
      );
      expect(store.getRitual(id)!.name, 'Sunday pancakes');

      store.close();
      final reopened = (await _tryOpen(dir))!;
      db = reopened;

      final raw = reopened.ritualBoxForTesting.get(id)!;
      expect(raw.name, startsWith('enc:v1:'));
      expect(raw.signature, startsWith('enc:v1:'));
      final read = reopened.getRitual(id)!;
      expect(read.name, 'Sunday pancakes');
      expect(read.signature, 'pancakes@sunday');
    },
  );
}
