import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/services/media/file_storage_service.dart';
import '../../../../data/models/entry.dart';

@visibleForTesting
Future<void> shareMemoryFiles({
  required List<XFile> files,
  required String text,
  required Rect shareOrigin,
}) {
  return Share.shareXFiles(
    files,
    text: text,
    subject: 'Shared from Seedling',
    sharePositionOrigin: shareOrigin,
  );
}

Future<void> showMemoryShareSheet(BuildContext context, Entry entry) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => MemoryShareSheet(entry: entry),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MemoryShareSheet(entry: entry),
  );
}

class MemoryShareSheet extends StatefulWidget {
  final Entry entry;

  const MemoryShareSheet({super.key, required this.entry});

  @override
  State<MemoryShareSheet> createState() => _MemoryShareSheetState();
}

class _MemoryShareSheetState extends State<MemoryShareSheet> {
  final _repaintKey = GlobalKey();
  final _captionController = TextEditingController();
  bool _attachOriginal = true;
  bool _isSharing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    final child = SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + mediaQuery.viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SeedlingColors.lightBark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Share memory',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: SeedlingColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        isIOS
                            ? CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  CupertinoIcons.xmark,
                                  color: SeedlingColors.textSecondary,
                                ),
                              )
                            : IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                                color: SeedlingColors.textSecondary,
                              ),
                      ],
                    ),
                    Text(
                      'Create a polished card for chat apps and social posts.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RepaintBoundary(
                      key: _repaintKey,
                      child: _MemoryShareCard(
                        entry: widget.entry,
                        caption: _captionController.text.trim(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCaptionField(context, isIOS),
                    FutureBuilder<String?>(
                      future: _attachableMediaPath(),
                      builder: (context, snapshot) {
                        final mediaPath = snapshot.data;
                        if (mediaPath == null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildAttachOriginalToggle(context, isIOS),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildShareButton(context, isIOS),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (isIOS) {
      return CupertinoPopupSurface(isSurfacePainted: false, child: child);
    }

    return child;
  }

  Widget _buildCaptionField(BuildContext context, bool isIOS) {
    if (isIOS) {
      return CupertinoTextField(
        controller: _captionController,
        maxLines: 3,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        padding: const EdgeInsets.all(14),
        placeholder: 'Add a note for the share post',
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        onChanged: (_) => setState(() {}),
      );
    }

    return TextField(
      controller: _captionController,
      maxLines: 3,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Caption',
        hintText: 'Add a note for the share post',
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildAttachOriginalToggle(BuildContext context, bool isIOS) {
    final title = widget.entry.type == EntryType.voice
        ? 'Attach original audio'
        : 'Attach original photo';

    if (isIOS) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  'The branded card will be shared either way.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: _attachOriginal,
            onChanged: (value) => setState(() => _attachOriginal = value),
          ),
        ],
      );
    }

    return SwitchListTile.adaptive(
      value: _attachOriginal,
      onChanged: (value) {
        setState(() => _attachOriginal = value);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: const Text('The branded card will be shared either way.'),
    );
  }

  Widget _buildShareButton(BuildContext context, bool isIOS) {
    if (isIOS) {
      return CupertinoButton.filled(
        onPressed: _isSharing ? null : _share,
        child: Text(_isSharing ? 'Preparing...' : 'Share memory'),
      );
    }

    return FilledButton.icon(
      onPressed: _isSharing ? null : _share,
      icon: _isSharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.share_outlined),
      label: Text(_isSharing ? 'Preparing...' : 'Share memory'),
    );
  }

  Future<void> _share() async {
    if (_isSharing) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.sizeOf(context);

    setState(() => _isSharing = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cardFile = File('${tempDir.path}/seedling_memory_$timestamp.png');
      await cardFile.writeAsBytes(byteData.buffer.asUint8List());

      final files = <XFile>[XFile(cardFile.path)];
      final mediaPath = await _attachableMediaPath();
      if (_attachOriginal && mediaPath != null) {
        files.add(XFile(mediaPath));
      }

      final shareOrigin = renderBox == null
          ? Rect.fromLTWH(0, 0, screenSize.width, screenSize.height)
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await shareMemoryFiles(
        files: files,
        text: _shareText(),
        shareOrigin: shareOrigin,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<String?> _attachableMediaPath() async {
    if (widget.entry.type != EntryType.photo &&
        widget.entry.type != EntryType.voice &&
        widget.entry.type != EntryType.object) {
      return null;
    }
    return FileStorageService.resolveMediaPath(widget.entry.mediaPath);
  }

  String _shareText() {
    final parts = <String>[];
    final caption = _captionController.text.trim();
    if (caption.isNotEmpty) {
      parts.add(caption);
    }
    parts.add('Shared from Seedling');
    return parts.join('\n\n');
  }
}

class _MemoryShareCard extends StatelessWidget {
  final Entry entry;
  final String caption;

  const _MemoryShareCard({required this.entry, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4E6870),
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF59767E), Color(0xFF465D64)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(
          color: SeedlingColors.warmWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 18),
            _buildHero(context),
            const SizedBox(height: 18),
            _buildBody(context),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SeedlingColors.creamPaper,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  caption,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SeedlingColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Seedling',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SeedlingColors.textMuted,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPECIMEN',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: SeedlingColors.textMuted,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _typeColor(entry.type).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                entry.typeName.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _typeColor(entry.type),
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateFormat('MMMM d, y').format(entry.createdAt),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    if ((entry.type == EntryType.photo || entry.type == EntryType.object) &&
        entry.hasMedia) {
      return FutureBuilder<String?>(
        future: FileStorageService.resolveMediaPath(entry.mediaPath),
        builder: (context, snapshot) {
          final resolvedPath = snapshot.data;
          if (resolvedPath == null) {
            return _placeholderHero(context);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.file(
              File(resolvedPath),
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholderHero(context),
            ),
          );
        },
      );
    }

    if (entry.type == EntryType.voice) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: SeedlingColors.softCream,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.multitrack_audio_outlined,
                    color: SeedlingColors.accentVoice,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Voice memo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SeedlingColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(18, (index) {
                  final heights = [16, 28, 18, 38, 22, 32, 20, 46, 26];
                  final height = heights[index % heights.length].toDouble();
                  return Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: height,
                        decoration: BoxDecoration(
                          color: SeedlingColors.accentVoice.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              Text(
                entry.transcription?.trim().isNotEmpty == true
                    ? entry.transcription!.trim()
                    : 'A preserved moment from your living tree.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SeedlingColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _placeholderHero(context);
  }

  Widget _placeholderHero(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SeedlingColors.softCream,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Icon(
          _typeIcon(entry.type),
          color: _typeColor(entry.type),
          size: 42,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final title = entry.title?.trim().isNotEmpty == true
        ? entry.title!.trim()
        : entry.typeName;
    final body = _bodyText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: SeedlingColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: SeedlingColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _bodyText() {
    final parts = <String>[];
    if (entry.type == EntryType.object &&
        entry.title?.trim().isNotEmpty == true &&
        entry.text?.trim().isNotEmpty == true) {
      parts.add(entry.text!.trim());
    } else if (entry.text?.trim().isNotEmpty == true) {
      parts.add(entry.text!.trim());
    }

    if (parts.isEmpty && entry.transcription?.trim().isNotEmpty == true) {
      parts.add(entry.transcription!.trim());
    }

    if (parts.isEmpty && entry.context?.trim().isNotEmpty == true) {
      parts.add(entry.context!.trim());
    }

    if (parts.isEmpty && entry.isCapsule) {
      parts.add(
        entry.isLocked
            ? entry.unlockTimeDescription
            : 'A time capsule that has opened back into the light.',
      );
    }

    if (parts.isEmpty) {
      parts.add('A preserved moment from your living tree.');
    }

    return parts.join('\n\n');
  }

  Color _typeColor(EntryType type) {
    return switch (type) {
      EntryType.line => SeedlingColors.accentLine,
      EntryType.photo => SeedlingColors.accentPhoto,
      EntryType.voice => SeedlingColors.accentVoice,
      EntryType.object => SeedlingColors.accentObject,
      EntryType.fragment => SeedlingColors.accentFragment,
      EntryType.ritual => SeedlingColors.accentRitual,
      EntryType.release => SeedlingColors.accentRelease,
    };
  }

  IconData _typeIcon(EntryType type) {
    return switch (type) {
      EntryType.line => Icons.format_quote_outlined,
      EntryType.photo => Icons.photo_outlined,
      EntryType.voice => Icons.graphic_eq,
      EntryType.object => Icons.category_outlined,
      EntryType.fragment => Icons.auto_awesome_outlined,
      EntryType.ritual => Icons.loop,
      EntryType.release => Icons.air,
    };
  }
}
