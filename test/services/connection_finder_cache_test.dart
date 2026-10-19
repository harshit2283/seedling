import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/connection_finder_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';

Entry _line(int id, String text, {int day = 1}) => Entry.line(text: text)
  ..id = id
  ..createdAt = DateTime(2026, 3, day);

void main() {
  group('ConnectionFinderService token cache', () {
    test('cached results match a cold run', () {
      final entries = [
        _line(1, 'walked the forest trail with grandma'),
        _line(2, 'forest trail again, grandma loved the birds'),
        _line(3, 'quarterly budget spreadsheet review', day: 20),
      ];
      final finder = ConnectionFinderService();
      final cold = finder.findConnections(entries[0], entries);
      final warm = finder.findConnections(entries[0], entries);
      final fresh = ConnectionFinderService().findConnections(
        entries[0],
        entries,
      );
      List<(int, double)> shape(List c) => [
        for (final x in c)
          (x.relatedEntry.id as int, x.similarityScore as double),
      ];
      expect(shape(warm), shape(cold));
      expect(shape(warm), shape(fresh));
      expect(cold.single.relatedEntry.id, 2);
    });

    test('editing an entry invalidates its cached tokens', () {
      final source = _line(1, 'walked the forest trail with grandma');
      final other = _line(2, 'forest trail again, grandma loved it');
      final finder = ConnectionFinderService();
      expect(finder.findConnections(source, [source, other]), isNotEmpty);

      other
        ..text = 'quarterly budget spreadsheet review'
        ..createdAt = DateTime(2026, 6, 1)
        ..invalidateSearchCache();
      expect(finder.findConnections(source, [source, other]), isEmpty);
    });
  });

  test('entryConnectionsProvider is released when nobody listens', () async {
    final entry = _line(1, 'a quiet morning');
    final container = ProviderContainer(
      overrides: [
        entriesProvider.overrideWithValue([entry]),
      ],
    );
    addTearDown(container.dispose);

    var disposed = false;
    final probe = Provider.autoDispose<int>((ref) {
      ref.onDispose(() => disposed = true);
      ref.watch(entryConnectionsProvider(1));
      return 0;
    });
    final sub = container.listen(probe, (_, _) {});
    expect(container.read(entryConnectionsProvider(1)), isEmpty);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isTrue);
    expect(container.exists(entryConnectionsProvider(1)), isFalse);
  });
}
