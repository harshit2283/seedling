import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('Entry.searchableLower', () {
    test('joins text/title/context/mood/transcription, lowercased', () {
      final entry = Entry(
        text: 'A Quiet Morning',
        title: 'Sunrise',
        context: 'Patio',
        mood: 'Calm',
        transcription: 'Birds Singing',
      );
      final result = entry.searchableLower;
      expect(result, contains('a quiet morning'));
      expect(result, contains('sunrise'));
      expect(result, contains('patio'));
      expect(result, contains('calm'));
      expect(result, contains('birds singing'));
      expect(result, isNot(contains('Quiet'))); // case-folded
    });

    test('memoises across reads', () {
      final entry = Entry(text: 'Hello World');
      final first = entry.searchableLower;
      final second = entry.searchableLower;
      expect(identical(first, second), isTrue);
    });

    test('invalidateSearchCache forces a re-compute on next read', () {
      final entry = Entry(text: 'Original');
      final first = entry.searchableLower;
      expect(first, contains('original'));

      entry.text = 'Updated';
      // Without invalidating, the cache still returns the old value.
      expect(entry.searchableLower, equals(first));

      entry.invalidateSearchCache();
      final second = entry.searchableLower;
      expect(second, contains('updated'));
      expect(identical(first, second), isFalse);
    });

    test('handles entirely-empty entries gracefully', () {
      final entry = Entry();
      expect(entry.searchableLower, isEmpty);
    });

    test('searchableContent delegates to searchableLower', () {
      final entry = Entry(text: 'Same Source');
      expect(entry.searchableContent, equals(entry.searchableLower));
    });
  });
}
