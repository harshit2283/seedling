import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/error_reporter.dart';

void main() {
  group('ErrorReporter', () {
    test('report does not throw when given an error', () {
      const reporter = ErrorReporter();
      expect(
        () => reporter.report(StateError('boom'), context: 'test'),
        returnsNormally,
      );
    });

    test('report tolerates a null stack', () {
      const reporter = ErrorReporter();
      expect(() => reporter.report('plain error'), returnsNormally);
    });
  });
}
