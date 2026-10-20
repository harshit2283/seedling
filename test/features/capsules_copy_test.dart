import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capsules/presentation/capsules_screen.dart';
import 'package:seedling/features/capsules/presentation/widgets/capsule_card.dart';

Entry capsule(String text, DateTime unlock, {String? title, int id = 1}) =>
    Entry.capsule(text: text, unlockDate: unlock)
      ..id = id
      ..title = title;

void main() {
  final later = DateTime(2030, 10, 4);
  final earlier = DateTime(2024, 3, 1);

  group('capsuleHeading', () {
    test('uses the capsule\'s own title when it has one', () {
      expect(capsuleHeading(capsule('x', later, title: 'For Ada')), 'For Ada');
    });

    test('otherwise names the day it opens', () {
      expect(capsuleHeading(capsule('x', later)), 'A letter to 4 October 2030');
    });
  });

  testWidgets('capsules screen: own words, sentence-case sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          capsulesProvider.overrideWithValue([
            capsule('See you on the other side', later, id: 1),
            capsule('Hello from last spring', earlier, id: 2),
          ]),
        ],
        child: MaterialApp(
          theme: SeedlingTheme.light,
          home: const CapsulesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting to open'), findsOneWidget);
    expect(find.text('Opened'), findsOneWidget);
    expect(find.text('LOCKED'), findsNothing);
    expect(find.text('UNLOCKED'), findsNothing);
    expect(find.text('Time Capsule'), findsNothing);
    expect(find.text('A letter to 4 October 2030'), findsOneWidget);
    expect(find.text('Hello from last spring'), findsOneWidget);
  });
}
