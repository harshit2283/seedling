import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Extracts a dominant color from [imageFile] by downscaling to 32x32 and
/// bucketing pixels into a 6x6x6 RGB cube. Excludes very-bright (>240) and
/// very-dark (<25) buckets to avoid washed-out or near-black accents.
///
/// Returns null if the image can't be decoded or no usable bucket is found.
Future<Color?> extractDominantColor(File imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
    final codec = await descriptor.instantiateCodec(
      targetWidth: 32,
      targetHeight: 32,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (raw == null) return null;
    return _bucketRgba(raw.buffer.asUint8List());
  } catch (e) {
    debugPrint('extractDominantColor failed: $e');
    return null;
  }
}

Color? _bucketRgba(Uint8List pixels) {
  // 6 buckets per channel = 216 buckets.
  final counts = List<int>.filled(216, 0);
  final rSums = List<int>.filled(216, 0);
  final gSums = List<int>.filled(216, 0);
  final bSums = List<int>.filled(216, 0);

  for (var i = 0; i + 3 < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a < 32) continue;
    // Skip very bright or very dark pixels.
    final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
    if (maxC > 240 && minC > 240) continue;
    if (maxC < 25) continue;
    final rb = (r * 6) ~/ 256;
    final gb = (g * 6) ~/ 256;
    final bb = (b * 6) ~/ 256;
    final idx = rb * 36 + gb * 6 + bb;
    counts[idx]++;
    rSums[idx] += r;
    gSums[idx] += g;
    bSums[idx] += b;
  }

  var bestIdx = -1;
  var bestCount = 0;
  for (var i = 0; i < counts.length; i++) {
    if (counts[i] > bestCount) {
      bestCount = counts[i];
      bestIdx = i;
    }
  }
  if (bestIdx < 0 || bestCount == 0) return null;
  final n = counts[bestIdx];
  return Color.fromARGB(
    255,
    (rSums[bestIdx] / n).round(),
    (gSums[bestIdx] / n).round(),
    (bSums[bestIdx] / n).round(),
  );
}
