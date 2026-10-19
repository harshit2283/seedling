import 'package:local_auth/local_auth.dart';
import '../error_reporter.dart';

/// Service responsible for biometric/device authentication.
class AppLockService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isSupported;
    } catch (e, st) {
      const ErrorReporter().report(
        e,
        stack: st,
        context: 'AppLockService.canAuthenticate',
      );
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock Seedling'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e, st) {
      const ErrorReporter().report(
        e,
        stack: st,
        context: 'AppLockService.authenticate',
      );
      return false;
    }
  }
}
