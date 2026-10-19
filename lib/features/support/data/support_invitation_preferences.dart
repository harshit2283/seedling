import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';

/// Remembers whether the one-time "support Seedling" invitation was shown.
///
/// The invitation is shown at most once in the lifetime of an install. It is
/// marked as shown the moment it first appears, so even ignoring it (never
/// tapping "Not now") means it will not come back. There is no counter, no
/// "remind me later", and no second attempt.
class SupportInvitationPreferences {
  SupportInvitationPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// True when the invitation has already been shown (or dismissed).
  bool get hasBeenShown =>
      _prefs.getBool(PrefsKeys.supportInvitationShown) ?? false;

  /// Claims the single showing. Returns true only the first time it is
  /// called; every later call returns false.
  bool claimShowing() {
    if (hasBeenShown) return false;
    // The in-memory cache updates synchronously; persistence follows.
    unawaited(_prefs.setBool(PrefsKeys.supportInvitationShown, true));
    return true;
  }
}
