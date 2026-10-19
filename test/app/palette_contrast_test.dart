import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/memory_card.dart';

import 'contrast_helpers.dart';

void main() {
  group('SeedlingPalette contrast', () {
    for (final palette in [SeedlingPalette.light, SeedlingPalette.dark]) {
      final name = palette.isDark ? 'dark' : 'light';
      test('$name: primary and secondary text reach AA on every surface', () {
        for (final bg in [palette.background, palette.surface, palette.card]) {
          expect(contrastRatio(palette.textPrimary, bg), greaterThan(4.5));
          expect(contrastRatio(palette.textSecondary, bg), greaterThan(4.5));
          expect(contrastRatio(palette.textMuted, bg), greaterThan(3.0));
          expect(contrastRatio(palette.primary, bg), greaterThan(4.5));
        }
        expect(
          contrastRatio(palette.onPrimaryFill, palette.primaryFill),
          greaterThan(4.5),
        );
      });

      test('$name: accent ink is readable on tinted badges', () {
        for (final accent in [
          palette.accentLine,
          palette.accentPhoto,
          palette.accentVoice,
          palette.accentObject,
          palette.accentFragment,
          palette.accentRitual,
          palette.accentRelease,
          palette.accentGold,
        ]) {
          final badge = composite(accent.withValues(alpha: 0.15), palette.card);
          expect(
            contrastRatio(palette.inkFor(accent), badge),
            greaterThan(4.5),
            reason: 'accent $accent',
          );
        }
      });
    }

    test('both themes register the palette extension', () {
      expect(SeedlingTheme.light.extension<SeedlingPalette>()!.isDark, false);
      expect(SeedlingTheme.dark.extension<SeedlingPalette>()!.isDark, true);
    });
  });

  group('MemoryCard text contrast', () {
    Future<void> pumpCard(WidgetTester tester, ThemeData theme) async {
      final entry = Entry.line(text: 'The light through the kitchen window')
        ..detectedTheme = 'family';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(body: MemoryCard(entry: entry)),
          ),
        ),
      );
    }

    for (final theme in [SeedlingTheme.light, SeedlingTheme.dark]) {
      final palette = theme.extension<SeedlingPalette>()!;
      testWidgets(
        '${palette.isDark ? 'dark' : 'light'}: every label is >= 4.5:1 and >= 12pt',
        (tester) async {
          await pumpCard(tester, theme);
          final texts = tester.widgetList<RichText>(find.byType(RichText));
          expect(texts, isNotEmpty);
          for (final rich in texts) {
            final style = rich.text.style!;
            final color = style.color!;
            expect(
              contrastRatio(color, palette.card),
              greaterThanOrEqualTo(4.5),
              reason: '"${rich.text.toPlainText()}" color $color',
            );
            expect(
              style.fontSize ?? 14,
              greaterThanOrEqualTo(12),
              reason: '"${rich.text.toPlainText()}" is too small',
            );
          }
        },
      );
    }
  });
}
