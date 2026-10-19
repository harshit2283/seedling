import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/data/models/entry.dart';

Entry _e(int id, String text, {int day = 1, String? theme}) =>
    Entry.line(text: text)
      ..id = id
      ..createdAt = DateTime(2026, 3, day)
      ..detectedTheme = theme;

List<int> _ids(List connections) => [
  for (final c in connections) c.relatedEntry.id as int,
];

void main() {
  group('ConnectionFinderService', () {
    test('theme and time alone never make a connection', () {
      final a = _e(1, 'Hiked up the ridge at dawn', theme: 'nature');
      final b = _e(2, 'Frogspawn in the pond!', theme: 'nature');
      expect(ConnectionFinderService().findConnections(a, [a, b]), isEmpty);
    });

    test('a rare shared word outweighs a common one', () {
      final corpus = [
        _e(1, 'Glazed my cups in speckled blue, kiln next week', day: 1),
        _e(2, 'Picked up the cups from the kiln', day: 2),
        _e(3, 'Coffee cups on the table again', day: 2),
        _e(4, 'More cups to wash', day: 3),
        _e(5, 'cups everywhere after the party', day: 4),
      ];
      // Same week for all, so only the words decide the order.
      final top = ConnectionFinderService().findConnections(corpus[0], corpus);
      expect(_ids(top).first, 2);
    });

    test('inflections match: cups/cup, glazed/glaze', () {
      final a = _e(1, 'glazed a small cup', day: 1);
      final b = _e(2, 'the glaze on my cups', day: 25);
      final c = _e(3, 'quarterly budget spreadsheet', day: 25);
      expect(_ids(ConnectionFinderService().findConnections(a, [a, b, c])), [
        2,
      ]);
    });

    test('mum, mom and mother are one person', () {
      final a = _e(1, 'Long phone call with Mum', day: 1);
      final b = _e(2, 'My mother turned seventy', day: 28);
      final c = _e(3, 'Planted tulips', day: 28);
      final connections = ConnectionFinderService().findConnections(a, [
        a,
        b,
        c,
      ]);
      expect(_ids(connections), [2]);
      expect(connections.single.factors.entityBonus, greaterThan(0));
      expect(connections.single.factors.primaryReason, 'People & places');
    });

    test("someone else's mum is not the user's mum", () {
      final a = _e(1, "Priya's wedding, her mum fed everyone", day: 1);
      final b = _e(2, "Mum's birthday tea", day: 28);
      final factors = ConnectionFinderService()
          .findConnections(a, [a, b])
          .map((c) => c.factors.entityBonus);
      expect(factors.every((f) => f == 0), isTrue);
    });

    test('names shared across entries connect them', () {
      final entries = [
        _e(1, 'Kick-off for Project Atlas today', day: 1),
        _e(2, 'We launched Atlas! Drinks after', day: 28),
        _e(3, 'We launched paper boats on the pond', day: 28),
      ];
      final top = ConnectionFinderService().findConnections(
        entries[0],
        entries,
      );
      expect(_ids(top), [2]);
    });

    test('corpus statistics follow the collection passed in', () {
      final finder = ConnectionFinderService();
      final a = _e(1, 'allotment tomatoes', day: 1);
      final b = _e(2, 'allotment courgettes', day: 28);
      final small = [a, b];
      final first = finder.findConnections(a, small).single.similarityScore;
      // Many more allotment entries make the word less distinctive.
      final big = [
        ...small,
        for (var i = 0; i < 20; i++) _e(10 + i, 'allotment day $i', day: 28),
      ];
      double scoreOf2() =>
          finder
              .findConnections(a, big)
              .where((c) => c.relatedEntry.id == 2)
              .map((c) => c.similarityScore)
              .firstOrNull ??
          0;
      final diluted = scoreOf2();
      expect(diluted, lessThan(first));
      // Same list again reuses the cached statistics and gives the same.
      final again = scoreOf2();
      expect(again, diluted);
    });

    test('scores stay within 0..1', () {
      final a = _e(1, 'Lisbon tram 28 with Sam', theme: 'travel');
      final b = _e(2, 'Lisbon tram 28 with Sam', theme: 'travel');
      final c = ConnectionFinderService().findConnections(a, [a, b]).single;
      expect(c.similarityScore, inInclusiveRange(0.0, 1.0));
      expect(c.isStrong, isTrue);
    });
  });
}
