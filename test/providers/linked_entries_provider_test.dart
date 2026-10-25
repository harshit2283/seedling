import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/datasources/local/seedling_database.dart';
import 'package:seedling/data/models/entry.dart';

class _MockDb extends Mock implements SeedlingDatabase {}

void main() {
  test('linked entries resolve once per link set, not once per build', () {
    final db = _MockDb();
    final linked = Entry.line(text: 'linked')..syncUUID = 'u1';
    when(() => db.getEntriesBySyncUUIDs(any())).thenReturn([linked]);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        allEntriesStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(linkedEntriesProvider('u1,u2'), (_, _) {});
    // Each detail-screen build looks the provider up again with an equal key.
    for (var i = 0; i < 10; i++) {
      expect(container.read(linkedEntriesProvider('u1,u2')), [linked]);
    }
    sub.close();

    verify(() => db.getEntriesBySyncUUIDs(['u1', 'u2'])).called(1);
    expect(container.read(linkedEntriesProvider('')), isEmpty);
    verifyNever(() => db.getEntriesBySyncUUIDs([]));
  });
}
