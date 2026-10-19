import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';

/// A memory's picture inside the year in review: decoded at the size it is
/// shown (never the full camera resolution) and opening the memory on tap.
class ReviewPhoto extends ConsumerWidget {
  const ReviewPhoto({
    super.key,
    required this.entry,
    required this.borderRadius,
  });

  final Entry entry;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = entry.mediaPath;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: borderRadius,
      ),
    );
    if (path == null || path.isEmpty) return placeholder;
    final file = ref.watch(resolvedMediaFileProvider(path)).value;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Semantics(
      button: true,
      image: true,
      label: entry.hasText ? entry.displayContent : 'Photo memory',
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.entryRoute(entry.id)),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (file == null) return placeholder;
              final w = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 400.0;
              return Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: (w * dpr).round(),
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A gentle mosaic of up to three pictures: one, a pair, or a large
/// picture beside two small ones.
class PhotoMosaic extends StatelessWidget {
  const PhotoMosaic({super.key, required this.photos, this.height = 168});

  final List<Entry> photos;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(3).toList();
    final r = BorderRadius.circular(10);
    const gap = 6.0;
    Widget tile(Entry e) => ReviewPhoto(entry: e, borderRadius: r);

    final Widget body = switch (shown.length) {
      0 => const SizedBox.shrink(),
      1 => tile(shown[0]),
      2 => Row(
        children: [
          Expanded(child: tile(shown[0])),
          const SizedBox(width: gap),
          Expanded(child: tile(shown[1])),
        ],
      ),
      _ => Row(
        children: [
          Expanded(flex: 3, child: tile(shown[0])),
          const SizedBox(width: gap),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: tile(shown[1])),
                const SizedBox(height: gap),
                Expanded(child: tile(shown[2])),
              ],
            ),
          ),
        ],
      ),
    };
    return SizedBox(height: height, child: body);
  }
}
