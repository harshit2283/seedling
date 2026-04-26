import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/entry_type_usage_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/ritual/ritual_service.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capture/domain/capture_intent.dart';

class _MockDatabase extends Mock implements ObjectBoxDatabase {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockRitualService extends Mock implements RitualService {}

class _MockUsageService extends Mock implements EntryTypeUsageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
    registerFallbackValue(SyncChangeType.create);
    registerFallbackValue(EntryType.line);
  });

  group('EntryCreatorNotifier.create(intent)', () {
    late _MockDatabase mockDb;
    late _MockSyncEngine mockSyncEngine;
    late _MockRitualService mockRitualService;
    late _MockUsageService mockUsageService;
    late ProviderContainer container;

    setUp(() {
      mockDb = _MockDatabase();
      mockSyncEngine = _MockSyncEngine();
      mockRitualService = _MockRitualService();
      mockUsageService = _MockUsageService();

      when(() => mockSyncEngine.ensureSyncUUID(any())).thenReturn(null);
      when(() => mockSyncEngine.queuePush(any(), any())).thenReturn(null);
      when(
        () => mockRitualService.updateAfterEntry(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockUsageService.recordUsage(
          any(),
          isCapsule: any(named: 'isCapsule'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockDb.saveEntry(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Entry,
      );

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          syncEngineProvider.overrideWithValue(mockSyncEngine),
          ritualServiceProvider.overrideWithValue(mockRitualService),
          entryTypeUsageServiceProvider.overrideWithValue(mockUsageService),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('LineCapture saves a LINE entry', () async {
      final notifier = container.read(entryCreatorProvider.notifier);

      final saved = await notifier.create(const LineCapture('hello'));

      expect(saved.type, EntryType.line);
      expect(saved.text, 'hello');
      verify(() => mockDb.saveEntry(any())).called(1);
    });

    test('PhotoCapture forwards mediaPath and text', () async {
      final notifier = container.read(entryCreatorProvider.notifier);

      final saved = await notifier.create(
        const PhotoCapture(mediaPath: '/tmp/photo.jpg', text: 'sunset'),
      );

      expect(saved.type, EntryType.photo);
      expect(saved.mediaPath, '/tmp/photo.jpg');
      expect(saved.text, 'sunset');
    });

    test('CapsuleCapture stamps the unlock date on the entry', () async {
      final notifier = container.read(entryCreatorProvider.notifier);
      final unlockDate = DateTime.now().add(const Duration(days: 30));

      final saved = await notifier.create(
        CapsuleCapture(text: 'future', unlockDate: unlockDate),
      );

      expect(saved.capsuleUnlockDate, unlockDate.toUtc());
      expect(saved.text, 'future');
    });
  });
}
