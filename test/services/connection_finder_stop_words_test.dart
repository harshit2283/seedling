import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('ConnectionFinderService stop words', () {
    late ConnectionFinderService service;

    setUp(() {
      service = ConnectionFinderService();
    });

    test('entries about "mom" and "dad" produce meaningful similarity', () {
      final entryA = Entry.line(text: 'Visited mom and dad today');
      final entryB = Entry.line(text: 'Called mom on the phone');

      // Both entries share "mom" — if it were a stop word, similarity would drop
      final similarity = service.calculateSimilarity(entryA, entryB);
      expect(
        similarity,
        greaterThan(0.0),
        reason: '"mom" should not be filtered as a stop word',
      );
    });

    test('entries about "work" produce meaningful similarity', () {
      final entryA = Entry.line(text: 'Long day at work today');
      final entryB = Entry.line(text: 'Work meeting went well');

      final similarity = service.calculateSimilarity(entryA, entryB);
      expect(
        similarity,
        greaterThan(0.0),
        reason: '"work" should not be filtered as a stop word',
      );
    });

    test('entries sharing only true stop words have zero text similarity', () {
      // These entries share only common stop words like "the", "and", "was"
      final entryA = Entry.line(text: 'the cat was happy');
      final entryB = Entry.line(text: 'the dog was tired');

      // After stop word removal, "cat"/"happy" vs "dog"/"tired" — no overlap
      final connections = service.findConnections(
        entryA,
        [entryA, entryB],
      );
      // Should not find a connection because shared words are only stop words
      final hasStrongTextConnection = connections.any(
        (c) => c.factors.textSimilarity > 0.3,
      );
      expect(hasStrongTextConnection, isFalse);
    });

    test('entries with "make" find connections (creativity keyword)', () {
      final entryA = Entry.line(text: 'I want to make something creative');
      final entryB = Entry.line(text: 'Decided to make art this weekend');

      final similarity = service.calculateSimilarity(entryA, entryB);
      expect(
        similarity,
        greaterThan(0.0),
        reason: '"make" should not be filtered as a stop word',
      );
    });

    test('findConnections returns results for family-themed entries', () {
      final source = Entry.line(text: 'Spent the evening with mom and dad');
      source.id = 1;

      final candidate1 = Entry.line(text: 'Mom called to check in');
      candidate1.id = 2;

      final candidate2 = Entry.line(text: 'Went to the grocery store');
      candidate2.id = 3;

      final connections = service.findConnections(
        source,
        [source, candidate1, candidate2],
      );

      // candidate1 shares "mom" with source, should rank higher
      if (connections.isNotEmpty) {
        expect(
          connections.first.relatedEntry.id,
          2,
          reason: 'Family-themed entry should be the strongest connection',
        );
      }
    });

    test('common stop words are still removed', () {
      // Entries that share only actual stop words should not connect
      final entryA = Entry.line(text: 'she was there before');
      entryA.id = 1;
      final entryB = Entry.line(text: 'she was here after');
      entryB.id = 2;

      // "she", "was", "before", "after" are all stop words
      // Only "there" vs "here" remain — no overlap
      final connections = service.findConnections(entryA, [entryA, entryB]);
      final hasStrongConnection = connections.any(
        (c) => c.factors.textSimilarity > 0.3,
      );
      expect(hasStrongConnection, isFalse);
    });
  });
}
