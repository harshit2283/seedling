import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/haptic_service.dart';
import 'package:seedling/core/services/providers.dart';

class _CountingHapticService implements HapticServiceInterface {
  int lightCount = 0;
  int selectionCount = 0;
  int mediumCount = 0;
  int heavyCount = 0;
  int entrySavedCount = 0;
  int capsuleCreatedCount = 0;
  int capsuleUnlockedCount = 0;
  MemoryTheme? lastTheme;

  @override
  void light() => lightCount++;

  @override
  void selection() => selectionCount++;

  @override
  void medium() => mediumCount++;

  @override
  void heavy() => heavyCount++;

  @override
  Future<void> onEntrySaved(MemoryTheme? theme) async {
    entrySavedCount++;
    lastTheme = theme;
  }

  @override
  Future<void> onCapsuleCreated() async {
    capsuleCreatedCount++;
  }

  @override
  Future<void> onCapsuleUnlocked() async {
    capsuleUnlockedCount++;
  }
}

void main() {
  group('hapticServiceProvider', () {
    test('default provider returns the production singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(hapticServiceProvider);
      expect(service, same(defaultHapticService));
    });

    test('can be overridden with a counting fake', () async {
      final fake = _CountingHapticService();
      final container = ProviderContainer(
        overrides: [hapticServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final service = container.read(hapticServiceProvider);
      await service.onEntrySaved(MemoryTheme.gratitude);

      expect(fake.entrySavedCount, 1);
      expect(fake.lastTheme, MemoryTheme.gratitude);
    });
  });
}
