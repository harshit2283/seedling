import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single sink for service-level errors.
///
/// In debug builds, logs via [debugPrint] using a consistent prefix so the
/// app's noise can be grepped. In release, this is a no-op until/unless we
/// wire up a crash reporter.
class ErrorReporter {
  const ErrorReporter();

  /// Report a swallowed-or-handled error with optional context.
  void report(Object error, {StackTrace? stack, String? context}) {
    if (!kDebugMode) return;
    final prefix = context == null ? 'ErrorReporter' : 'ErrorReporter $context';
    debugPrint('[$prefix] $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
}

/// Provider exposing a singleton [ErrorReporter].
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return const ErrorReporter();
});
