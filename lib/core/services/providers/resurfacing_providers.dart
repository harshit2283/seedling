import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/tree/domain/resurfacing.dart';
import '../../constants/prefs_keys.dart';
import 'database_providers.dart';
import 'settings_providers.dart';

// ============================================================================
// Gentle resurfacing ("From your tree")
// ============================================================================

/// The clock resurfacing uses; overridden in tests.
final resurfaceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Today's calendar day key. Ticks over at local midnight so the
/// resurfaced memory and the "dismissed for today" state roll over even when
/// nothing is saved.
class ResurfaceDayNotifier extends Notifier<String> {
  Timer? _midnight;

  @override
  String build() {
    final clock = ref.watch(resurfaceClockProvider);
    ref.onDispose(() => _midnight?.cancel());
    _scheduleRollover(clock);
    return resurfaceDayKey(clock());
  }

  void _scheduleRollover(DateTime Function() clock) {
    _midnight?.cancel();
    final now = clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      state = resurfaceDayKey(clock());
      _scheduleRollover(clock);
    });
  }
}

final resurfaceDayProvider = NotifierProvider<ResurfaceDayNotifier, String>(
  ResurfaceDayNotifier.new,
);

/// Today's resurfaced memory, or null when nothing is old enough yet.
///
/// On-this-day memories from earlier years come first; otherwise a memory at
/// least 30 days old, rotated once a day. Never a sealed capsule, never
/// anything in the trash, never something the person let go of.
final resurfacedMemoryProvider = Provider<ResurfacedMemory?>((ref) {
  final entries = ref.watch(allEntriesProvider);
  ref.watch(resurfaceDayProvider);
  final now = ref.watch(resurfaceClockProvider)();
  return pickResurfacedMemory(entries, now);
});

/// Whether there is anything worth resurfacing at all. The weekly nudge is
/// only scheduled when this is true, so it never promises an empty tree.
final hasResurfaceableMemoryProvider = Provider<bool>((ref) {
  return ref.watch(resurfacedMemoryProvider) != null;
});

/// Whether today's card was dismissed. Resets on the next calendar day.
class ResurfaceDismissedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final today = ref.watch(resurfaceDayProvider);
    return prefs.getString(PrefsKeys.resurfaceDismissedDate) == today;
  }

  Future<void> dismissForToday() async {
    state = true;
    final prefs = ref.read(sharedPreferencesProvider);
    final today = resurfaceDayKey(ref.read(resurfaceClockProvider)());
    await prefs.setString(PrefsKeys.resurfaceDismissedDate, today);
  }
}

final resurfaceDismissedTodayProvider =
    NotifierProvider<ResurfaceDismissedNotifier, bool>(
      ResurfaceDismissedNotifier.new,
    );

/// Opt-in (off by default) weekly "A memory is waiting for you" notification.
class ResurfaceNotificationsNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(PrefsKeys.resurfaceNotificationsEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefsKeys.resurfaceNotificationsEnabled, enabled);
    await ref
        .read(gentleReminderServiceProvider)
        .scheduleResurfacingNudge(
          enabled: enabled,
          hasMemory: ref.read(hasResurfaceableMemoryProvider),
        );
  }
}

final resurfaceNotificationsEnabledProvider =
    NotifierProvider<ResurfaceNotificationsNotifier, bool>(
      ResurfaceNotificationsNotifier.new,
    );

/// Keeps the weekly nudge scheduled while it is enabled (and cancels it if
/// the tree has nothing to resurface). Does nothing while the setting is off,
/// so it never keeps the all-entries stream alive for people who opted out.
final resurfaceNotificationAutoScheduleProvider = Provider<void>((ref) {
  final enabled = ref.watch(resurfaceNotificationsEnabledProvider);
  if (!enabled) return;
  final hasMemory = ref.watch(hasResurfaceableMemoryProvider);
  final service = ref.watch(gentleReminderServiceProvider);
  unawaited(
    service.scheduleResurfacingNudge(enabled: true, hasMemory: hasMemory),
  );
});
