import 'package:flutter/services.dart';
import 'ai/models/memory_theme.dart';

/// Instance-based haptic interface so tests can substitute a fake.
///
/// Production code may keep using the static [HapticService] facade for
/// brevity; new code that needs to be testable should depend on this
/// interface (via [hapticServiceProvider]) instead.
abstract class HapticServiceInterface {
  void light();
  void selection();
  void medium();
  void heavy();
  Future<void> onEntrySaved(MemoryTheme? theme);
  Future<void> onCapsuleCreated();
  Future<void> onCapsuleUnlocked();
}

/// Default implementation that calls [HapticFeedback] directly.
class _DefaultHapticService implements HapticServiceInterface {
  const _DefaultHapticService();

  @override
  void light() {
    HapticFeedback.lightImpact();
  }

  @override
  void selection() {
    HapticFeedback.selectionClick();
  }

  @override
  void medium() {
    HapticFeedback.mediumImpact();
  }

  @override
  void heavy() {
    HapticFeedback.heavyImpact();
  }

  @override
  Future<void> onEntrySaved(MemoryTheme? theme) async {
    switch (theme) {
      case MemoryTheme.gratitude:
        // Double light tap - celebratory warmth
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
        break;

      case MemoryTheme.nature:
        // Light then selection - organic, flowing
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 80));
        HapticFeedback.selectionClick();
        break;

      case MemoryTheme.reflection:
        // Medium then light - thoughtful, settling
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        HapticFeedback.lightImpact();
        break;

      case MemoryTheme.family:
      case MemoryTheme.friends:
        // Double selection - connected, bonding
        HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 80));
        HapticFeedback.selectionClick();
        break;

      case MemoryTheme.travel:
        // Selection-light-selection - journey, movement
        HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 70));
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 70));
        HapticFeedback.selectionClick();
        break;

      case MemoryTheme.creativity:
        // Triple light rapid - playful, energetic
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        HapticFeedback.lightImpact();
        break;

      case MemoryTheme.health:
        // Medium then light - strong start, gentle finish
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
        break;

      case MemoryTheme.food:
        // Light then medium - savoring
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.mediumImpact();
        break;

      case MemoryTheme.work:
        // Single firm medium - accomplishment
        HapticFeedback.mediumImpact();
        break;

      case MemoryTheme.moments:
      case null:
        // Standard light - simple, default
        HapticFeedback.lightImpact();
        break;
    }
  }

  @override
  Future<void> onCapsuleCreated() async {
    // Light-medium-light pattern - sealing something precious
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  @override
  Future<void> onCapsuleUnlocked() async {
    // Building excitement pattern
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    HapticFeedback.heavyImpact();
  }
}

/// Default singleton used by the static [HapticService] facade.
const HapticServiceInterface defaultHapticService = _DefaultHapticService();

/// Centralized haptic feedback service with theme-aware patterns.
///
/// Static facade preserved for backwards compatibility; delegates to the
/// default singleton. New code should prefer injecting
/// [HapticServiceInterface] via the riverpod provider so tests can override.
class HapticService {
  HapticService._();

  /// Light tap - for confirmations, dismissals, subtle feedback
  static void light() => defaultHapticService.light();

  /// Selection click - for button taps, navigation, toggles
  static void selection() => defaultHapticService.selection();

  /// Medium impact - for significant actions (recording start, filter changes)
  static void medium() => defaultHapticService.medium();

  /// Heavy impact - for critical actions (max duration, permanent delete)
  static void heavy() => defaultHapticService.heavy();

  /// Theme-specific haptic pattern when saving an entry.
  static Future<void> onEntrySaved(MemoryTheme? theme) =>
      defaultHapticService.onEntrySaved(theme);

  /// Haptic for creating a time capsule - anticipatory, hopeful.
  static Future<void> onCapsuleCreated() =>
      defaultHapticService.onCapsuleCreated();

  /// Haptic for unlocking a time capsule - exciting, revealing.
  static Future<void> onCapsuleUnlocked() =>
      defaultHapticService.onCapsuleUnlocked();
}
