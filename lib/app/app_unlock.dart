import 'package:flutter/foundation.dart';

import '../core/services/security/app_lock_service.dart';

/// What happened when the person tapped Unlock.
enum UnlockOutcome {
  /// The device confirmed it is them.
  unlocked,

  /// They cancelled, or the check failed. The app stays locked.
  stillLocked,

  /// The device can no longer check anyone (Face ID, Touch ID and the
  /// passcode were all removed). The app lock only ever relied on the
  /// device's own security, so it is turned off rather than shutting the
  /// person out of their own memories for good.
  lockTurnedOff,
}

/// Shown once when [UnlockOutcome.lockTurnedOff] happens.
const lockTurnedOffMessage =
    'This device no longer has a passcode or Face ID, so the Seedling lock '
    'is off. Set one up again, then turn the lock back on in Settings.';

/// Runs the unlock flow against the device's own security.
///
/// Authentication allows the device passcode as a fallback (see
/// [AppLockService.authenticate]), so a person without biometrics can still
/// get in. Only when the device cannot authenticate at all is the lock
/// turned off via [turnLockOff].
Future<UnlockOutcome> unlockWithDeviceSecurity({
  required AppLockService service,
  required Future<void> Function() turnLockOff,
}) async {
  if (!await service.canAuthenticate()) {
    await turnLockOff();
    return UnlockOutcome.lockTurnedOff;
  }
  final didUnlock = await service.authenticate();
  return didUnlock ? UnlockOutcome.unlocked : UnlockOutcome.stillLocked;
}

/// Holds an action that must not run behind the lock (opening the capture
/// sheet from a home-widget link, say) until the app is unlocked.
class UnlockDeferredAction {
  VoidCallback? _pending;

  /// Whether an action is waiting for the unlock.
  bool get hasPending => _pending != null;

  /// Runs [action] now when unlocked; otherwise keeps it (replacing any
  /// earlier one) until [unlocked].
  void run({required bool locked, required VoidCallback action}) {
    if (locked) {
      _pending = action;
    } else {
      action();
    }
  }

  /// The app was unlocked: run whatever was waiting, once.
  void unlocked() {
    final action = _pending;
    _pending = null;
    action?.call();
  }
}
