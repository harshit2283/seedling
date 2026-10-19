import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/capture/presentation/widgets/entry_type_button.dart';
import 'package:seedling/features/memories/presentation/memory_reader_screen.dart';
import 'package:seedling/features/prompts/data/prompt_repository.dart';
import 'package:seedling/features/prompts/presentation/prompt_card.dart';

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

  group('EntryTypeButton', () {
    for (final theme in [SeedlingTheme.light, SeedlingTheme.dark]) {
      final palette = theme.extension<SeedlingPalette>()!;
      final name = palette.isDark ? 'dark' : 'light';

      testWidgets('$name: unselected label stays AA and >= 12pt', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            EntryTypeButton(
              icon: Icons.format_quote,
              label: 'Line',
              color: palette.accentLine,
              isSelected: false,
              onTap: () {},
            ),
            theme: theme,
          ),
        );
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.text('Line'),
            matching: find.byType(RichText),
          ),
        );
        final style = rich.text.style!;
        expect(
          contrastRatio(style.color!, palette.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(style.fontSize, greaterThanOrEqualTo(12));
        final size = tester.getSize(find.byType(EntryTypeButton));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      });
    }

    testWidgets('exposes selected state to assistive tech', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EntryTypeButton(
                icon: Icons.format_quote,
                label: 'Line',
                color: SeedlingPalette.light.accentLine,
                isSelected: true,
                onTap: () {},
              ),
              EntryTypeButton(
                icon: Icons.photo,
                label: 'Photo',
                color: SeedlingPalette.light.accentPhoto,
                isSelected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Line')),
        isSemantics(isButton: true, hasSelectedState: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Photo')),
        isSemantics(isButton: true, hasSelectedState: true, isSelected: false),
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
