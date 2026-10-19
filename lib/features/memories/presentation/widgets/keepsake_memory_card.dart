import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../core/services/media/file_storage_service.dart';
import '../../../../data/models/entry.dart';

/// Width of a [KeepsakeMemoryCard]; rows of them use [keepsakeRowHeight].
const double keepsakeCardWidth = 132;

/// Height a horizontal row of [KeepsakeMemoryCard]s needs at the default
/// text size; see [keepsakeRowHeightFor] for larger text.
const double keepsakeRowHeight = 178;

/// Height a row of cards needs with [scaler]: the 120pt panel, the gap, a
/// caption line and the date line, both of which grow with the text size.
double keepsakeRowHeightFor(TextScaler scaler) {
  final lines = scaler.scale(13) * 1.3 + scaler.scale(12) * 1.4;
  final needed = (120 + 8 + lines + 2).ceilToDouble();
  return needed > keepsakeRowHeight ? needed : keepsakeRowHeight;
}

/// Serif family for keepsake surfaces (dates, titles, memory text).
///
/// Georgia ships on both iOS and Android-adjacent font stacks; `serif` is the
/// platform fallback so text never drops to a missing glyph.
const String keepsakeSerif = 'Georgia';
const List<String> keepsakeSerifFallback = ['serif', 'Noto Serif'];

/// Accent color for an entry type, from the adaptive palette.
Color typeAccent(SeedlingPalette palette, EntryType type) => switch (type) {
  EntryType.line => palette.accentLine,
  EntryType.photo => palette.accentPhoto,
  EntryType.voice => palette.accentVoice,
  EntryType.object => palette.accentObject,
  EntryType.fragment => palette.accentFragment,
  EntryType.ritual => palette.accentRitual,
  EntryType.release => palette.accentRelease,
};

/// A small memory card for "Related memories" and "Linked memories" rows.
///
/// Photo memories show their photo; everything else shows its own words on a
/// soft tint of its type color, like a note tucked between pages.
class KeepsakeMemoryCard extends StatefulWidget {
  const KeepsakeMemoryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.semanticHint,
  });

  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticHint;

  @override
  State<KeepsakeMemoryCard> createState() => _KeepsakeMemoryCardState();
}

class _KeepsakeMemoryCardState extends State<KeepsakeMemoryCard> {
  Future<File?>? _photo;

  bool get _hasPhoto =>
      widget.entry.hasMedia &&
      (widget.entry.type == EntryType.photo ||
          widget.entry.type == EntryType.object);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant KeepsakeMemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.mediaPath != widget.entry.mediaPath) _resolve();
  }

  void _resolve() {
    _photo = _hasPhoto
        ? FileStorageService.resolveMediaFile(widget.entry.mediaPath)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = widget.entry;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final date = DateFormat.yMMM(locale).format(entry.createdAt);
    final accent = typeAccent(palette, entry.type);

    Widget wordsPanel() => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      color: Color.alphaBlend(
        accent.withValues(alpha: palette.isDark ? 0.22 : 0.14),
        palette.card,
      ),
      child: Text(
        entry.displayContent,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: keepsakeSerif,
          fontFamilyFallback: keepsakeSerifFallback,
          fontSize: 13.5,
          height: 1.4,
          fontStyle: FontStyle.italic,
          color: palette.textPrimary,
        ),
      ),
    );

    final panel = _photo == null
        ? wordsPanel()
        : FutureBuilder<File?>(
            future: _photo,
            builder: (context, snap) {
              final file = snap.data;
              if (snap.connectionState != ConnectionState.done) {
                return ColoredBox(color: palette.surfaceMuted);
              }
              if (file == null) return wordsPanel();
              return Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 360,
                errorBuilder: (context, error, stack) => wordsPanel(),
              );
            },
          );

    return Semantics(
      button: true,
      label: '${entry.displayContent}, $date',
      hint: widget.semanticHint,
      excludeSemantics: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: keepsakeCardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: SeedlingRadius.small,
                child: SizedBox(
                  height: 120,
                  width: keepsakeCardWidth,
                  child: panel,
                ),
              ),
              const SizedBox(height: 8),
              if (_hasPhoto)
                Text(
                  entry.displayContent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: palette.textPrimary,
                  ),
                ),
              Text(
                date,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet section label ("Related memories", "Linked memories").
class KeepsakeSectionLabel extends StatelessWidget {
  const KeepsakeSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: keepsakeSerif,
          fontFamilyFallback: keepsakeSerifFallback,
          fontSize: 17,
          fontStyle: FontStyle.italic,
          color: context.palette.textSecondary,
        ),
      ),
    );
  }
}

/// A horizontal row of [KeepsakeMemoryCard]s with page-aligned padding.
class KeepsakeMemoryRow extends StatelessWidget {
  const KeepsakeMemoryRow({
    super.key,
    required this.entries,
    required this.onOpen,
    this.onLongPress,
    this.semanticHint,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final List<Entry> entries;
  final ValueChanged<Entry> onOpen;
  final ValueChanged<Entry>? onLongPress;
  final String? semanticHint;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: keepsakeRowHeightFor(MediaQuery.textScalerOf(context)),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final e = entries[i];
          return KeepsakeMemoryCard(
            key: ValueKey('keepsake-${e.id}'),
            entry: e,
            onTap: () => onOpen(e),
            onLongPress: onLongPress == null ? null : () => onLongPress!(e),
            semanticHint: semanticHint,
          );
        },
      ),
    );
  }
}
