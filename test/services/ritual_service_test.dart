import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/models/ritual_candidate.dart';
import 'package:seedling/data/models/ritual.dart';

void main() {
  group('Ritual model', () {
    test('default constructor sets correct defaults', () {
      final ritual = Ritual(
        name: 'Morning walk',
        signature: 'morning:walk',
        cadenceDays: 7,
        occurrenceCount: 3,
      );

      expect(ritual.name, 'Morning walk');
      expect(ritual.signature, 'morning:walk');
      expect(ritual.cadenceDays, 7);
      expect(ritual.occurrenceCount, 3);
      expect(ritual.status, RitualStatus.active);
      expect(ritual.uuid, isNotEmpty);
      expect(ritual.id, 0);
    });

    test('status getter/setter uses statusIndex', () {
      final ritual = Ritual();

      ritual.status = RitualStatus.paused;
      expect(ritual.statusIndex, RitualStatus.paused.index);
      expect(ritual.status, RitualStatus.paused);

      ritual.status = RitualStatus.archived;
      expect(ritual.statusIndex, RitualStatus.archived.index);
      expect(ritual.status, RitualStatus.archived);

      ritual.status = RitualStatus.active;
      expect(ritual.status, RitualStatus.active);
    });

    test('cadenceDescription returns correct labels', () {
      expect(Ritual(cadenceDays: 1).cadenceDescription, 'Daily');
      expect(Ritual(cadenceDays: 3).cadenceDescription, 'Every 3 days');
      expect(Ritual(cadenceDays: 7).cadenceDescription, 'Weekly');
      expect(Ritual(cadenceDays: 14).cadenceDescription, 'Biweekly');
      expect(Ritual(cadenceDays: 5).cadenceDescription, 'Every 5 days');
    });

    test('isDue returns true when nextDueAt is in the past', () {
      final ritual = Ritual();
      ritual.nextDueAt = DateTime.now().subtract(const Duration(hours: 1));

      expect(ritual.isDue, true);
    });

    test('isDue returns false when nextDueAt is in the future', () {
      final ritual = Ritual();
      ritual.nextDueAt = DateTime.now().add(const Duration(hours: 1));

      expect(ritual.isDue, false);
    });

    test('isDue returns false when nextDueAt is null', () {
      final ritual = Ritual();
      ritual.nextDueAt = null;

      expect(ritual.isDue, false);
    });

    test('daysSinceLastObserved returns correct value', () {
      final ritual = Ritual();
      ritual.lastObservedAt = DateTime.now().subtract(const Duration(days: 3));

      expect(ritual.daysSinceLastObserved, 3);
    });

    test('daysSinceLastObserved returns null when never observed', () {
      final ritual = Ritual();
      ritual.lastObservedAt = null;

      expect(ritual.daysSinceLastObserved, isNull);
    });
  });

  group('RitualStatus extension', () {
    test('label returns correct strings', () {
      expect(RitualStatus.active.label, 'Active');
      expect(RitualStatus.paused.label, 'Paused');
      expect(RitualStatus.archived.label, 'Archived');
    });
  });

  group('RitualCandidate', () {
    test('spanDays computes correct difference', () {
      final candidate = RitualCandidate(
        signature: 'test:sig',
        occurrences: 5,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 15),
        sampleText: 'sample',
      );

      expect(candidate.spanDays, 14);
    });

    test('occurrences is stored correctly', () {
      final candidate = RitualCandidate(
        signature: 'morning:coffee',
        occurrences: 12,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
        sampleText: 'Morning coffee',
      );

      expect(candidate.occurrences, 12);
      expect(candidate.signature, 'morning:coffee');
      expect(candidate.sampleText, 'Morning coffee');
    });
  });
}
