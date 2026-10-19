import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks the maximum observed wall-clock time, persisted in secure storage,
/// so callers can detect device clock rollback.
///
/// Used by capsule visibility gates: if the user (or an attacker) sets the
/// device clock backwards, capsules should not become unlockable as a result.
class ClockGuardService {
  static const _storageKey = 'clock_guard_max_observed_now_v1';
  static const Duration _tamperThreshold = Duration(hours: 24);

  final FlutterSecureStorage _storage;
  DateTime? _cachedMax;
  bool _initialized = false;

  ClockGuardService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Hydrate the cached max from secure storage. Safe to call repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        _cachedMax = DateTime.tryParse(raw)?.toUtc();
      }
    } catch (e) {
      debugPrint('ClockGuardService.init read failed: $e');
    }
    _initialized = true;
    await trustedNow();
  }

  /// Returns the larger of (system now, max observed now), in UTC, and
  /// persists if the system clock has advanced.
  Future<DateTime> trustedNow() async {
    final now = DateTime.now().toUtc();
    final max = _cachedMax;
    if (max == null || now.isAfter(max)) {
      _cachedMax = now;
      try {
        await _storage.write(key: _storageKey, value: now.toIso8601String());
      } catch (e) {
        debugPrint('ClockGuardService.trustedNow write failed: $e');
      }
      return now;
    }
    return max;
  }

  /// Synchronous accessor for the most recent trusted "now" already cached.
  /// Useful inside DB query builders that cannot await.
  DateTime? cachedTrustedNow() => _cachedMax;

  /// Returns true when the system clock is materially earlier than the highest
  /// previously observed clock value (likely tampering or extreme drift).
  Future<bool> isLikelyClockTampered() async {
    final max = _cachedMax;
    if (max == null) return false;
    final now = DateTime.now().toUtc();
    return max.difference(now) > _tamperThreshold;
  }
}
