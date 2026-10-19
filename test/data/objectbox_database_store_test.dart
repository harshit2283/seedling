// Runs against a real ObjectBox store. Needs the native library
// (libobjectbox.so / .dylib) on the loader path; skipped otherwise.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/security/at_rest_encryption_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

Future<ObjectBoxDatabase?> _tryOpen(Directory dir) async {
  try {
    return await ObjectBoxDatabase.openForTesting(
      directory: dir.path,
      encryptionService: AtRestEncryptionService(),
    );
  } on ArgumentError catch (e) {
    // Native library missing ("Failed to load dynamic library").
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
    dir = await Directory.systemTemp.createTemp('obx_test');
    db = await _tryOpen(dir);
  });

  tearDown(() async {
    db?.close();
    await dir.delete(recursive: true);
  });

  test(
    'soft delete and restore bump modifiedAt so sync propagates them',
    () async {
      final store = db;
      if (store == null) {
        markTestSkipped('ObjectBox native library not available');
        return;
      }
      final saved = await store.saveEntry(Entry.line(text: 'a quiet morning'));
      final before = store.getEntry(saved.id)!.modifiedAt!;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.softDeleteEntry(saved.id);
      final afterDelete = store.getEntry(saved.id)!.modifiedAt!;
      expect(afterDelete.isAfter(before), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.restoreEntry(saved.id);
      final afterRestore = store.getEntry(saved.id)!.modifiedAt!;
      expect(afterRestore.isAfter(afterDelete), isTrue);
    },
  );

  test('text is stored encrypted and read back decrypted', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'grandma\'s ring'));
    expect(store.getEntry(saved.id)!.text, "grandma's ring");
  });

  test('soft delete then restore keeps the tree count stable', () async {
    final store = db;
    if (store == null) {
      markTestSkipped('ObjectBox native library not available');
      return;
    }
    final saved = await store.saveEntry(Entry.line(text: 'one'));
    final countBefore = store.currentTree!.entryCount;
    await store.softDeleteEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore - 1);
    await store.restoreEntry(saved.id);
    expect(store.currentTree!.entryCount, countBefore);
  });
}
