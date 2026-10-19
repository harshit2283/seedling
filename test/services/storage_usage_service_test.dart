import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/core/services/media/file_storage_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/storage/storage_usage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';

class _Paths extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _Paths(this.support, this.documents);

  final String support;
  final String documents;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

/// Counts how often the storage service is asked to measure.
class _CountingService extends StorageUsageService {
  int calls = 0;

  @override
  Future<StorageUsage> calculateUsage() async {
    calls++;
    return StorageUsage(photosBytes: calls);
  }
}

class _MockDb extends Mock implements ObjectBoxDatabase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('seedling_storage_usage_');
    // Support and documents are different folders on device, as on iOS.
    final support = Directory('${root.path}/support')..createSync();
    final documents = Directory('${root.path}/documents')..createSync();
    PathProviderPlatform.instance = _Paths(support.path, documents.path);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('counts media where FileStorageService actually saves it', () async {
    final storage = FileStorageService();
    await storage.init();

    final photo = File('${root.path}/pick.jpg')
      ..writeAsBytesSync(List.filled(2048, 1));
    final voice = File('${root.path}/rec.m4a')
      ..writeAsBytesSync(List.filled(1000, 2));
    final savedPhoto = await storage.savePhoto(photo);
    final savedVoice = await storage.saveVoice(voice.path);
    expect(await File(savedPhoto).exists(), isTrue);
    expect(await File(savedVoice).exists(), isTrue);

    // The database lives where ObjectBoxDatabase opens it.
    final store = Directory(await ObjectBoxDatabase.defaultStoreDirectory())
      ..createSync(recursive: true);
    File('${store.path}/data.mdb').writeAsBytesSync(List.filled(4096, 0));

    final usage = await StorageUsageService().calculateUsage();
    expect(usage.photosBytes, 2048);
    expect(usage.voicesBytes, 1000);
    expect(usage.databaseBytes, 4096);
    expect(usage.totalFormatted, isNot('0 B'));
  });

  test('storage figure is re-measured when memories change', () async {
    final db = _MockDb();
    final entries = StreamController<List<Entry>>();
    addTearDown(entries.close);
    when(() => db.watchAllEntries()).thenAnswer((_) => entries.stream);
    final service = _CountingService();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        storageUsageServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(storageUsageProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(storageUsageProvider.future);
    final before = service.calls;

    entries.add([Entry.photo(mediaPath: '/x/photos/a.jpg')]);
    await Future<void>.delayed(Duration.zero);
    await container.read(storageUsageProvider.future);
    expect(service.calls, greaterThan(before));
  });
}
