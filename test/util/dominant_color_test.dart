import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/util/dominant_color.dart';

Future<File> _writePngFile(
  int r,
  int g,
  int b, {
  required Directory dir,
}) async {
  final pixels = Uint8List(32 * 32 * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = r;
    pixels[i + 1] = g;
    pixels[i + 2] = b;
    pixels[i + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    32,
    32,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/test_${r}_${g}_$b.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dominant_color_test');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('extractDominantColor', () {
    test('returns null for a missing file', () async {
      final missing = File('${tempDir.path}/nonexistent.png');
      expect(await extractDominantColor(missing), isNull);
    });

    test('returns null for a malformed image', () async {
      final bad = File('${tempDir.path}/bad.png');
      await bad.writeAsBytes(Uint8List.fromList([0, 1, 2, 3, 4]));
      expect(await extractDominantColor(bad), isNull);
    });

    test('extracts a saturated mid-tone color', () async {
      final file = await _writePngFile(120, 60, 200, dir: tempDir);
      final color = await extractDominantColor(file);
      expect(color, isNotNull);
      // Bucketing snaps each channel to a ~42-wide bucket; the averaged
      // bucket value should be within roughly that distance of the source.
      expect((color!.r * 255).round(), closeTo(120, 30));
      expect((color.g * 255).round(), closeTo(60, 30));
      expect((color.b * 255).round(), closeTo(200, 30));
    });

    test('returns null for pure white (excluded as too bright)', () async {
      final file = await _writePngFile(255, 255, 255, dir: tempDir);
      expect(await extractDominantColor(file), isNull);
    });

    test('returns null for near-black (excluded as too dark)', () async {
      final file = await _writePngFile(8, 8, 8, dir: tempDir);
      expect(await extractDominantColor(file), isNull);
    });
  });
}
