import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/review/domain/review_generator.dart';
import 'package:seedling/features/review/presentation/widgets/shareable_card.dart';

// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

const _secret = 'The night I told Sam about the diagnosis';

void main() {
  late File photoFile;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('share_card_test');
    photoFile = File('${dir.path}/p.png')..writeAsBytesSync(_png);
  });

  Entry photo(int id, int month) =>
      Entry.photo(mediaPath: '/media/photos/$id.jpg', text: _secret)
        ..id = id
        ..createdAt = DateTime(2025, month, 3);

  YearReviewData data() => YearReviewData(
    year: 2025,
    totalEntries: 120,
    seasons: {
      'spring': SeasonData(
        name: 'Spring',
        entryCount: 30,
        sampleSnippet: _secret,
        photos: [photo(1, 4)],
      ),
      'summer': SeasonData(
        name: 'Summer',
        entryCount: 30,
        photos: [photo(2, 7)],
      ),
      'autumn': SeasonData(
        name: 'Autumn',
        entryCount: 30,
        photos: [photo(3, 10)],
      ),
      'winter': SeasonData(
        name: 'Winter',
        entryCount: 30,
        photos: [photo(4, 1)],
      ),
    },
    themeDistribution: const {MemoryTheme.nature: 40},
    dominantTheme: MemoryTheme.nature,
    memorableMoments: [photo(1, 4)],
    treeStateLabel: 'Young tree',
    monthCounts: const [4, 0, 9, 12, 8, 15, 20, 10, 6, 14, 12, 10],
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedMediaFileProvider.overrideWith((ref, path) => photoFile),
        ],
        child: MaterialApp(
          theme: SeedlingTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareableCard(
                reviewData: data(),
                isDark: false,
                finished: true,
                now: DateTime(2026, 2, 1),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Iterable<String> cardTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(ShareCardFace),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');

  Finder cardImages() => find.descendant(
    of: find.byType(ShareCardFace),
    matching: find.byType(Image),
  );

  testWidgets('by default: year, tree, months and one line, nothing private', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('My 2025'), findsOneWidget);
    expect(find.text('Young tree, grown from 120 memories'), findsOneWidget);
    expect(find.byType(MonthDotStrip), findsOneWidget);
    expect(cardImages(), findsNothing);
    for (final text in cardTexts(tester)) {
      expect(text, isNot(contains('diagnosis')));
    }
  });

  testWidgets('season photos appear only after the person turns them on', (
    tester,
  ) async {
    await pump(tester);
    expect(cardImages(), findsNothing);

    await tester.tap(find.byKey(const ValueKey('share-card-photos-toggle')));
    await tester.pumpAndSettle();

    expect(cardImages(), findsNWidgets(4));
    expect(find.byType(MonthDotStrip), findsNothing);
    // Even with photos, no words from the memories.
    for (final text in cardTexts(tester)) {
      expect(text, isNot(contains('diagnosis')));
    }
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('diagnosis')), findsNothing);
    semantics.dispose();

    await tester.tap(find.byKey(const ValueKey('share-card-photos-toggle')));
    await tester.pumpAndSettle();
    expect(cardImages(), findsNothing);
  });

  test('calm line keeps no score', () {
    expect(shareCardLine(data(), calm: true), 'A year of nature');
    expect(shareCardLine(data(), calm: false), contains('120'));
  });
}
