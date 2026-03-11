import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('Entry.manualLinkList', () {
    test('parses comma-separated string correctly', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = 'uuid-1,uuid-2,uuid-3';

      expect(entry.manualLinkList, ['uuid-1', 'uuid-2', 'uuid-3']);
    });

    test('returns empty list for null manualLinkIds', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = null;

      expect(entry.manualLinkList, isEmpty);
    });

    test('returns empty list for empty string manualLinkIds', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = '';

      expect(entry.manualLinkList, isEmpty);
    });

    test('handles single UUID', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = 'single-uuid';

      expect(entry.manualLinkList, ['single-uuid']);
    });
  });

  group('Entry.hasManualLinks', () {
    test('returns true when manualLinkIds is non-empty', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = 'uuid-1,uuid-2';

      expect(entry.hasManualLinks, true);
    });

    test('returns false when manualLinkIds is null', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = null;

      expect(entry.hasManualLinks, false);
    });

    test('returns false when manualLinkIds is empty', () {
      final entry = Entry.line(text: 'test');
      entry.manualLinkIds = '';

      expect(entry.hasManualLinks, false);
    });
  });
}
