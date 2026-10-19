import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/diagnostics_log.dart';
import 'package:seedling/core/services/error_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diag_test');
  });

  tearDown(() async {
    DiagnosticsLog.instance = null;
    await dir.delete(recursive: true);
  });

  group('DiagnosticsLog.redact', () {
    test('removes absolute paths', () {
      final out = DiagnosticsLog.redact(
        'image validation failed for /var/mobile/Containers/Data/Application/'
        'ABC/Documents/media/photos/abc.jpg: bad header',
      );
      expect(out, isNot(contains('/var/mobile')));
      expect(out, isNot(contains('abc.jpg')));
      expect(out, contains('<path>'));
      expect(out, contains('bad header'));
    });

    test('removes quoted values, URIs and emails', () {
      final out = DiagnosticsLog.redact(
        'Bad state: "Dinner with Sam" failed for file:///private/x.m4a '
        'by someone@example.com',
      );
      expect(out, isNot(contains('Sam')));
      expect(out, isNot(contains('x.m4a')));
      expect(out, isNot(contains('someone@example.com')));
    });

    test('truncates long messages', () {
      expect(DiagnosticsLog.redact('x' * 1000).length, lessThanOrEqualTo(201));
    });

    test('FormatException never stores the source text it was parsing', () {
      final out = DiagnosticsLog.describe(
        const FormatException('Unexpected character', 'my secret memory'),
      );
      expect(out, isNot(contains('my secret memory')));
      expect(out, contains('Unexpected character'));
    });
  });

  group('DiagnosticsLog storage', () {
    test('keeps only the most recent 200 entries, across restarts', () async {
      final log = await DiagnosticsLog.open(directory: dir);
      for (var i = 0; i < 250; i++) {
        log.record(StateError('error $i'));
      }
      await log.flush();
      expect(log.entries.length, DiagnosticsLog.maxEntries);
      expect(log.entries.first.message, contains('error 50'));
      expect(log.entries.last.message, contains('error 249'));

      final reopened = await DiagnosticsLog.open(directory: dir);
      expect(reopened.entries.length, DiagnosticsLog.maxEntries);
      expect(reopened.entries.last.message, contains('error 249'));
    });

    test('stored file never contains redacted content', () async {
      final log = await DiagnosticsLog.open(directory: dir);
      log.record(
        FileSystemException(
          'Cannot open',
          '/data/user/0/com.seedling/files/media/voices/1234.m4a',
        ),
        context: 'ShareReceiver',
      );
      await log.flush();
      final raw = await File(
        '${dir.path}/${DiagnosticsLog.fileName}',
      ).readAsString();
      expect(raw, isNot(contains('1234.m4a')));
      expect(raw, isNot(contains('/data/user')));
      expect(log.exportText(), contains('Cannot open'));
    });
  });

  group('ErrorReporter', () {
    test('records reported errors in the diagnostics log', () async {
      DiagnosticsLog.instance = await DiagnosticsLog.open(directory: dir);
      const ErrorReporter().report(StateError('boom'), context: 'test');
      expect(DiagnosticsLog.instance!.entries.single.context, 'test');
    });

    test('global handlers report and mark platform errors handled', () async {
      DiagnosticsLog.instance = await DiagnosticsLog.open(directory: dir);
      final previousFlutter = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
      });

      installGlobalErrorHandlers(const ErrorReporter());
      final handled = PlatformDispatcher.instance.onError!(
        StateError('platform'),
        StackTrace.current,
      );
      // Restore before anything else can hit the test framework's handler.
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;

      expect(handled, isTrue);
      expect(
        DiagnosticsLog.instance!.entries.single.context,
        'PlatformDispatcher',
      );
    });
  });
}
