import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/ritual.dart';

void main() {
  group('Ritual UUID generation', () {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('generates valid UUID v4 format', () {
      final ritual = Ritual(name: 'Test ritual', cadenceDays: 7);
      expect(
        uuidRegex.hasMatch(ritual.uuid),
        isTrue,
        reason: 'Ritual UUID should be a valid v4 UUID, got: ${ritual.uuid}',
      );
    });

    test('generates unique UUIDs for different rituals', () {
      final uuids = <String>{};
      for (var i = 0; i < 100; i++) {
        final ritual = Ritual(name: 'Ritual $i', cadenceDays: 1);
        expect(
          uuids.add(ritual.uuid),
          isTrue,
          reason: 'UUID collision at iteration $i: ${ritual.uuid}',
        );
      }
    });

    test('preserves explicitly provided UUID', () {
      const explicitUuid = '550e8400-e29b-41d4-a716-446655440000';
      final ritual = Ritual(uuid: explicitUuid, name: 'Test', cadenceDays: 7);

      expect(ritual.uuid, explicitUuid);
    });

    test('two rituals created at the same time have different UUIDs', () {
      final ritual1 = Ritual(name: 'First', cadenceDays: 1);
      final ritual2 = Ritual(name: 'Second', cadenceDays: 1);

      expect(
        ritual1.uuid,
        isNot(equals(ritual2.uuid)),
        reason: 'Simultaneously created rituals must have distinct UUIDs',
      );
    });
  });
}
