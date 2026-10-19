import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostics_log.dart';

/// Single sink for service-level errors.
///
/// - Debug builds: logs via [debugPrint] with a consistent prefix.
/// - All builds: appends a redacted entry to the on-device
///   [DiagnosticsLog] (when initialized). Nothing is sent anywhere; the
///   person can choose to share it from Settings > About.
///
/// Release builds never print, so paths and error text don't end up in
/// system logs (`debugPrint` is not stripped in release).
class ErrorReporter {
  const ErrorReporter();

  /// Report a swallowed-or-handled error with optional context.
  void report(Object error, {StackTrace? stack, String? context}) {
    try {
      DiagnosticsLog.instance?.record(error, stack: stack, context: context);
    } catch (_) {
      // Reporting must never throw.
    }
    if (!kDebugMode) return;
    final prefix = context == null ? 'ErrorReporter' : 'ErrorReporter $context';
    debugPrint('[$prefix] $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
}

/// Routes framework and platform errors to [reporter].
///
/// - [FlutterError.onError] reports (and still presents the error in debug).
/// - [PlatformDispatcher.onError] reports and returns true so the engine
///   treats the error as handled instead of printing it.
void installGlobalErrorHandlers(ErrorReporter reporter) {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) FlutterError.presentError(details);
    reporter.report(
      details.exception,
      stack: details.stack,
      context: 'FlutterError',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reporter.report(error, stack: stack, context: 'PlatformDispatcher');
    return true;
  };
}

/// Provider exposing a singleton [ErrorReporter].
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return const ErrorReporter();
});
