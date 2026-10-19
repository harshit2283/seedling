import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors scripts/check_palette.sh so `flutter test` catches regressions:
/// feature widgets must read colors from `context.palette` so they adapt to
/// dark mode, instead of hard-coding the light-only constants.
void main() {
  const allowlist = {
    // Procedural tree painter: white highlights are part of the artwork.
    'lib/features/tree/presentation/animated_tree_visualization.dart',
    // Full-screen photo viewer is always black, like the system Photos app.
    'lib/features/memories/presentation/widgets/photo_viewer.dart',
  };
  final pattern = RegExp(
    r'SeedlingColors\.(text[A-Za-z]*|forestGreen\b)|Colors\.(white|black)',
  );

  test('lib/features uses context.palette, not light-only colors', () {
    final offenders = <String>[];
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (allowlist.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('// palette: allow')) continue;
        if (pattern.hasMatch(line)) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use context.palette instead:\n${offenders.join('\n')}',
    );
  });
}
