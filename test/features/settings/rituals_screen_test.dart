import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/platform/platform_utils.dart';
import 'package:seedling/core/services/ai/models/ritual_candidate.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/data/models/ritual.dart';
import 'package:seedling/features/settings/domain/ritual_memory_groups.dart';
import 'package:seedling/features/settings/presentation/rituals_screen.dart';

Entry ritual(String title, DateTime at, {String? text, int id = 0}) =>
    Entry.ritual(title: title, text: text)
      ..id = id
      ..createdAt = at;

Widget host({
  required List<Entry> entries,
  List<Ritual> kept = const [],
  List<RitualCandidate> candidates = const [],
}) {
  return ProviderScope(
    overrides: [
      allEntriesProvider.overrideWithValue(entries),
      ritualsStreamProvider.overrideWith((ref) => Stream.value(kept)),
      ritualCandidatesProvider.overrideWithValue(candidates),
    ],
    child: MaterialApp(theme: SeedlingTheme.light, home: const RitualsScreen()),
  );
}

void main() {
  tearDown(() => PlatformUtils.debugIsIOSOverride = null);

  group('groupRitualMemories', () {
    test('groups ritual memories by title, ignoring case and spacing', () {
      final groups = groupRitualMemories([
        ritual('Sunday coffee on the balcony', DateTime(2026, 9, 7)),
        ritual('sunday  coffee on the balcony ', DateTime(2026, 9, 14)),
        ritual('Evening walk', DateTime(2026, 9, 10)),
        Entry.line(text: 'Sunday coffee on the balcony'),
      ]);
      expect(groups, hasLength(2));
      expect(groups.first.count, 2);
      expect(groups.first.title, 'sunday  coffee on the balcony');
      expect(groups.first.lastAt, DateTime(2026, 9, 14));
      expect(groups.last.title, 'Evening walk');
    });

    test('leaves out deleted memories and capsules still waiting', () {
      final deleted = ritual('Tea', DateTime(2026, 1, 1))..isDeleted = true;
      final waiting = ritual('Tea', DateTime(2026, 1, 2))
        ..capsuleUnlockDate = DateTime.now().add(const Duration(days: 30));
      expect(groupRitualMemories([deleted, waiting]), isEmpty);
    });
  });

  group('RitualsScreen', () {
    testWidgets('lists a saved ritual memory instead of "No rituals yet"', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          entries: [
            ritual('Sunday coffee on the balcony', DateTime(2026, 9, 7), id: 1),
            ritual(
              'Sunday coffee on the balcony',
              DateTime(2026, 9, 14),
              id: 2,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No rituals yet'), findsNothing);
      expect(find.text(ritualsExplainer), findsOneWidget);
      expect(find.text('Your rituals'), findsOneWidget);
      expect(find.text('Sunday coffee on the balcony'), findsOneWidget);
      expect(find.textContaining('Twice'), findsOneWidget);
    });

    testWidgets('tapping a ritual shows each occurrence', (tester) async {
      await tester.pumpWidget(
        host(
          entries: [
            ritual(
              'Evening walk',
              DateTime(2026, 9, 7),
              id: 1,
              text: 'Fog by the river',
            ),
            ritual('Evening walk', DateTime(2026, 9, 14), id: 2),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evening walk'));
      await tester.pumpAndSettle();

      expect(find.byType(RitualOccurrencesScreen), findsOneWidget);
      expect(find.text('Each time'), findsOneWidget);
      expect(find.text('Monday, 14 September 2026'), findsOneWidget);
      expect(find.text('Monday, 7 September 2026'), findsOneWidget);
      expect(find.text('Fog by the river'), findsOneWidget);
    });

    testWidgets('detected patterns appear below as suggestions', (
      tester,
    ) async {
      PlatformUtils.debugIsIOSOverride = true;
      final now = DateTime.now();
      await tester.pumpWidget(
        host(
          entries: [ritual('Evening walk', now, id: 1)],
          candidates: [
            RitualCandidate(
              signature: 'morning:bread-oven-sourdough',
              occurrences: 4,
              firstSeen: now.subtract(const Duration(days: 30)),
              lastSeen: now,
              sampleText: 'Sourdough out of the oven',
            ),
            // Already a named ritual: not suggested again.
            RitualCandidate(
              signature: 'evening:evening-walk',
              occurrences: 3,
              firstSeen: now.subtract(const Duration(days: 30)),
              lastSeen: now,
              sampleText: 'Evening walk',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seedling noticed'), findsOneWidget);
      expect(find.text('Sourdough out of the oven'), findsOneWidget);
      expect(find.text('Often in the morning · 4 times'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      final suggestionTop = tester
          .getTopLeft(find.text('Sourdough out of the oven'))
          .dy;
      final ritualTop = tester.getTopLeft(find.text('Evening walk')).dy;
      expect(suggestionTop, greaterThan(ritualTop));
    });

    testWidgets('empty state explains how to start a ritual', (tester) async {
      await tester.pumpWidget(host(entries: const []));
      await tester.pumpAndSettle();
      expect(find.text('No rituals yet'), findsOneWidget);
      expect(find.textContaining('Choose Ritual'), findsOneWidget);
    });
  });
}
