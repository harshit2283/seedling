import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capture/presentation/quick_capture_sheet.dart';
import 'package:seedling/features/memories/presentation/memory_reader_screen.dart';
import 'package:seedling/features/prompts/data/prompt_repository.dart';
import 'package:seedling/features/prompts/presentation/prompt_card.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/contrast_helpers.dart';

Widget _host(Widget child, {ThemeData? theme, bool reduceMotion = false}) {
  return MaterialApp(
    theme: theme ?? SeedlingTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  const prompt = GentlePrompt(
    text: 'What made you smile today?',
    category: PromptCategory.general,
  );

  group('PromptCard', () {
    testWidgets('dismiss button is labelled and at least 44x44', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var dismissed = false;
      await tester.pumpWidget(
        _host(
          PromptCard(
            prompt: prompt,
            onTap: () {},
            onDismiss: () => dismissed = true,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final dismiss = find.bySemanticsLabel('Dismiss prompt');
      expect(dismiss, findsOneWidget);
      final size = tester.getSize(dismiss);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(dismiss);
      await tester.pump();
      expect(dismissed, isTrue, reason: 'Reduce Motion dismisses at once');
      handle.dispose();
    });

    testWidgets('Reduce Motion shows the card without sliding', (tester) async {
      await tester.pumpWidget(
        _host(
          PromptCard(prompt: prompt, onTap: () {}, onDismiss: () {}),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(prompt.text),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1.0);
      // Let the delayed forward() timer complete.
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Quick capture controls', () {
    Future<void> pumpSheet(WidgetTester tester, ThemeData theme) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: _host(const QuickCaptureSheet(), theme: theme),
        ),
      );
      await tester.pump();
    }

    for (final theme in [SeedlingTheme.light, SeedlingTheme.dark]) {
      final palette = theme.extension<SeedlingPalette>()!;
      final name = palette.isDark ? 'dark' : 'light';

      testWidgets('$name: idle labels stay AA, >= 12pt, 44pt targets', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpSheet(tester, theme);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        for (final label in [
          'Photo',
          'Voice',
          'Title',
          'More',
          'Let go',
          'Ritual',
          'Capsule',
        ]) {
          final rich = tester.widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          final style = rich.text.style!;
          expect(
            contrastRatio(style.color!, palette.surface),
            greaterThanOrEqualTo(4.5),
            reason: label,
          );
          expect(style.fontSize, greaterThanOrEqualTo(12), reason: label);
        }
        for (final label in [
          'Add a photo',
          'Record a voice memo',
          'Add a title',
          'Let go mode',
          'Ritual mode',
          'Enable capsule mode',
          'Hide Let go, Ritual and Capsule',
        ]) {
          final size = tester.getSize(find.bySemanticsLabel(label));
          expect(size.height, greaterThanOrEqualTo(44), reason: label);
          expect(size.width, greaterThanOrEqualTo(44), reason: label);
        }
        handle.dispose();
      });
    }

    testWidgets('mode chips expose selected state to assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(tester, SeedlingTheme.light);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let go'));
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Let go mode')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Ritual mode')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('MemoryReaderScreen (non-iOS)', () {
    testWidgets('renders the full reader with 44pt+ labelled controls', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final entries = [
        Entry.line(text: 'First light on the lake'),
        Entry.line(text: 'Bread rising on the counter'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlingTheme.dark,
          home: MemoryReaderScreen(
            args: MemoryReaderArgs(entries: entries, initialIndex: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('First light on the lake'), findsOneWidget);
      expect(find.text('Open memory details'), findsNothing);
      for (final label in [
        'Back',
        'Switch reader style',
        'Hide details',
        'Open details',
      ]) {
        final control = find.bySemanticsLabel(label);
        expect(control, findsOneWidget, reason: label);
        final size = tester.getSize(control);
        expect(size.shortestSide, greaterThanOrEqualTo(44), reason: label);
      }
      // Drain the chrome auto-hide timer.
      await tester.pump(const Duration(seconds: 5));
      handle.dispose();
    });
  });
}
