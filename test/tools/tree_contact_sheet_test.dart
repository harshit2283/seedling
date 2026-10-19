// Renders every tree stage x season in light and dark mode to PNG contact
// sheets, for looking at the illustration while working on it.
//
// Skipped by default. Run with:
//   TREE_CONTACT_SHEET=1 flutter test test/tools/tree_contact_sheet_test.dart
// Output goes to $TREE_CONTACT_SHEET_DIR (default build/tree_contact_sheet).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/models/season.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/domain/tree_personality.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';

final _enabled = Platform.environment['TREE_CONTACT_SHEET'] != null;
final _outDir =
    Platform.environment['TREE_CONTACT_SHEET_DIR'] ??
    'build/tree_contact_sheet';

class _Cell {
  const _Cell(
    this.state,
    this.progress,
    this.season, {
    this.lights = 0,
    this.personality,
  });
  final TreeState state;
  final double progress;
  final Season season;
  final int lights;
  final TreePersonality? personality;
}

Widget _sheet(List<List<_Cell>> rows, {required bool dark, required Key key}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? SeedlingTheme.dark : SeedlingTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Builder(
          builder: (context) => ColoredBox(
            color: context.palette.background,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final row in rows)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final cell in row)
                              Container(
                                width: 272,
                                height: 340,
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.palette.card,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: AnimatedTreeVisualization(
                                  state: cell.state,
                                  progress: cell.progress,
                                  season: cell.season,
                                  seed: 2026,
                                  memoryLights: cell.lights,
                                  personality: cell.personality,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _render(
  WidgetTester tester,
  List<List<_Cell>> rows,
  String name, {
  required bool dark,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(
    (rows.first.length * 284 + 24) * 2.0,
    (rows.length * 352 + 24) * 2.0,
  );
  addTearDown(tester.view.reset);
  const key = ValueKey('sheet');
  await tester.pumpWidget(_sheet(rows, dark: dark, key: key));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  final seasons = Season.values;
  List<List<_Cell>> stagesBySeason(double progress, {int lights = 0}) => [
    for (final state in TreeState.values)
      [
        for (final season in seasons)
          _Cell(state, progress, season, lights: lights),
      ],
  ];

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('contact sheet: stages x seasons ($mode)', (tester) async {
      await _render(
        tester,
        stagesBySeason(0.5, lights: 3),
        'stages_$mode',
        dark: dark,
      );
    }, skip: !_enabled);

    testWidgets('contact sheet: growth within stages ($mode)', (tester) async {
      final rows = [
        for (final state in TreeState.values.skip(2))
          [
            for (final p in [0.0, 0.33, 0.66, 0.99])
              _Cell(state, p, Season.summer),
          ],
      ];
      await _render(tester, rows, 'growth_$mode', dark: dark);
    }, skip: !_enabled);
  }

  testWidgets('contact sheet: personalities and memory lights', (tester) async {
    final gratitude = TreePersonality.fromDistribution(const {
      MemoryTheme.gratitude: 6,
    });
    final rows = [
      [
        _Cell(TreeState.matureTree, 0.6, Season.summer, lights: 7),
        _Cell(TreeState.ancientTree, 1, Season.spring, lights: 5),
        _Cell(TreeState.youngTree, 0.4, Season.autumn, lights: 2),
        _Cell(TreeState.matureTree, 0.4, Season.summer, personality: gratitude),
      ],
    ];
    await _render(tester, rows, 'extras_light', dark: false);
  }, skip: !_enabled);
}
