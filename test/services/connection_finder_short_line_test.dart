import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  final now = DateTime(2026, 10, 1);
  var nextId = 1;
  Entry line(String text, int daysAgo) => Entry.line(text: text)
    ..id = nextId++
    ..createdAt = now.subtract(Duration(days: daysAgo));

  test('a short line finds memories that share one of its few words', () {
    final coffee = line('Morning coffee on the balcony', 0);
    final all = [
      coffee,
      line('Coffee with Sam at the corner place', 20),
      line('The balcony tomatoes finally turned red', 40),
      line('Rain all afternoon', 2),
      line('Grandma laughing at her own joke', 60),
    ];
    final related = ConnectionFinderService()
        .findConnections(coffee, all)
        .map((c) => c.relatedEntry.text)
        .toList();
    expect(
      related,
      containsAll([
        'Coffee with Sam at the corner place',
        'The balcony tomatoes finally turned red',
      ]),
    );
    expect(related, isNot(contains('Rain all afternoon')));
  });

  test('a long entry still needs the full threshold', () {
    final long = line(
      'We drove up through the pass in the early light, stopped for '
      'pastries in the village, and reached the lake before the wind rose',
      0,
    );
    final all = [long, line('Pastries', 300)];
    expect(ConnectionFinderService().findConnections(long, all), isEmpty);
  });
}
