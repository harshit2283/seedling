import 'package:flutter/services.dart';
import 'ai/models/memory_theme.dart';

/// Centralized haptic feedback service with theme-aware patterns
///
/// Provides consistent haptic feedback across the app, with special
/// patterns for different memory themes to create subtle emotional
/// associations with different types of memories.
class HapticService {
  HapticService._();

  // ─────────────────────────────────────────────────────────────────
  // Standard Haptics (existing patterns formalized)
  // ─────────────────────────────────────────────────────────────────

  /// Light tap - for confirmations, dismissals, subtle feedback
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Selection click - for button taps, navigation, toggles
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Medium impact - for significant actions (recording start, filter changes)
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for critical actions (max duration, permanent delete)
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  // ─────────────────────────────────────────────────────────────────
  // Theme-Based Haptics (Phase 4.5)
  // ─────────────────────────────────────────────────────────────────

  /// Theme-specific haptic pattern when saving an entry
  ///
  /// Each theme has a subtle but distinct haptic signature:
  /// - Gratitude: Double light tap (celebratory, warm)
  /// - Release: Single medium (letting go, weight lifted)
  /// - Nature: Light followed by selection (organic, flowing)
  /// - Reflection: Medium followed by light (thoughtful, settling)
  /// - Family/Friends: Double selection (connected, bonding)
  /// - Travel: Selection-light-selection (journey, movement)
  /// - Creativity: Triple light rapid (playful, energetic)
  /// - Health: Medium-light (strong start, gentle finish)
  /// - Food: Light-medium (savoring)
  /// - Work: Single firm medium (accomplishment)
  /// - Moments: Standard light (default, simple)
  static Future<void> onEntrySaved(MemoryTheme? theme) async {
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

  // ─────────────────────────────────────────────────────────────────
  // Capsule-Specific Haptics (Phase 4.5)
  // ─────────────────────────────────────────────────────────────────

  /// Haptic for creating a time capsule - anticipatory, hopeful
  static Future<void> onCapsuleCreated() async {
    // Light-medium-light pattern - sealing something precious
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  /// Haptic for unlocking a time capsule - exciting, revealing
  static Future<void> onCapsuleUnlocked() async {
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
