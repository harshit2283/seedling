import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/share/share_receiver_service.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../data/models/entry.dart';

/// Shows a sheet for handling content shared from other apps
void showSharedContentSheet(BuildContext context, SharedContent content) {
  HapticFeedback.lightImpact();

  if (PlatformUtils.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => SharedContentSheet(content: content),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SharedContentSheet(content: content),
    );
  }
}

/// Sheet for saving content shared from other apps
class SharedContentSheet extends ConsumerStatefulWidget {
  final SharedContent content;

  const SharedContentSheet({super.key, required this.content});

  @override
  ConsumerState<SharedContentSheet> createState() => _SharedContentSheetState();
}

class _SharedContentSheetState extends ConsumerState<SharedContentSheet> {
  final _textController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill text if sharing text/URL
    if (widget.content.text != null) {
      _textController.text = widget.content.text!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final textMuted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    final accentColor = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    final content = Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PlatformUtils.isIOS
                  ? CupertinoColors.systemGrey3
                  : SeedlingColors.lightBark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getTypeIcon(), color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save to Seedling',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _getTypeDescription(),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Content preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildContentPreview(isDark, textPrimary, textMuted),
          ),

          const SizedBox(height: 20),

          // Save button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: _isSaving
                  ? Center(
                      child: PlatformUtils.isIOS
                          ? const CupertinoActivityIndicator()
                          : const CircularProgressIndicator(),
                    )
                  : PlatformUtils.isIOS
                  ? CupertinoButton.filled(
                      onPressed: _saveEntry,
                      child: const Text('Save Memory'),
                    )
                  : ElevatedButton(
                      onPressed: _saveEntry,
                      child: const Text('Save Memory'),
                    ),
            ),
          ),

          SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );

    return GlassSheet(
      backgroundColor: isDark
          ? SeedlingColors.surfaceDark
          : SeedlingColors.warmWhite,
      opacity: PlatformUtils.isIOS ? 0.85 : 1.0,
      child: content,
    );
  }

  IconData _getTypeIcon() {
    switch (widget.content.type) {
      case SharedContentType.text:
        return PlatformUtils.isIOS
            ? CupertinoIcons.text_quote
            : Icons.format_quote;
      case SharedContentType.url:
        return PlatformUtils.isIOS ? CupertinoIcons.link : Icons.link;
      case SharedContentType.image:
        return PlatformUtils.isIOS ? CupertinoIcons.photo : Icons.photo;
    }
  }

  String _getTypeDescription() {
    switch (widget.content.type) {
      case SharedContentType.text:
        return switch (widget.content.suggestedType) {
          EntryType.fragment => 'Saving as a Fragment',
          EntryType.release => 'Saving as a Release',
          EntryType.ritual => 'Saving as a Ritual',
          _ => 'Saving as a Line entry',
        };
      case SharedContentType.url:
        return 'Saving link as a Line entry';
      case SharedContentType.image:
        return 'Saving as a Photo entry';
    }
  }

  Widget _buildContentPreview(bool isDark, Color textPrimary, Color textMuted) {
    final cardColor = isDark
        ? SeedlingColors.cardDark
        : SeedlingColors.softCream;
    final borderColor = isDark
        ? SeedlingColors.borderDark
        : SeedlingColors.softCream;

    switch (widget.content.type) {
      case SharedContentType.text:
      case SharedContentType.url:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: _buildTextField(isDark, textPrimary, textMuted),
        );

      case SharedContentType.image:
        return Column(
          children: [
            // Image preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(widget.content.imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Optional caption
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: _buildTextField(
                isDark,
                textPrimary,
                textMuted,
                hint: 'Add a caption (optional)',
              ),
            ),
          ],
        );
    }
  }

  Widget _buildTextField(
    bool isDark,
    Color textPrimary,
    Color textMuted, {
    String? hint,
  }) {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        maxLines: widget.content.type == SharedContentType.image ? 2 : 4,
        minLines: widget.content.type == SharedContentType.image ? 1 : 2,
        textCapitalization: TextCapitalization.sentences,
        placeholder: hint ?? 'Edit before saving...',
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        style: TextStyle(fontSize: 16, color: textPrimary),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.zero,
      );
    }

    return TextField(
      controller: _textController,
      maxLines: widget.content.type == SharedContentType.image ? 2 : 4,
      minLines: widget.content.type == SharedContentType.image ? 1 : 2,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: textPrimary),
      decoration: InputDecoration(
        hintText: hint ?? 'Edit before saving...',
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: textMuted),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final creator = ref.read(entryCreatorProvider.notifier);
      final text = _textController.text.trim();

      switch (widget.content.type) {
        case SharedContentType.text:
        case SharedContentType.url:
          if (text.isNotEmpty) {
            await switch (widget.content.suggestedType) {
              EntryType.fragment => creator.createFragmentEntry(text),
              EntryType.release => creator.createReleaseEntry(text),
              EntryType.ritual => creator.createRitualEntry(text),
              _ => creator.createLineEntry(text),
            };
          }
          break;

        case SharedContentType.image:
          if (widget.content.imagePath != null) {
            // Copy the shared image to our storage first
            final photoService = ref.read(photoCaptureServiceProvider);
            final result = await photoService.saveExistingImage(
              widget.content.imagePath!,
            );
            if (result.isSuccess && result.path != null) {
              await creator.createPhotoEntry(
                result.path!,
                text: text.isEmpty ? null : text,
              );
            }
          }
          break;
      }

      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_sanitizeErrorForUser(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _sanitizeErrorForUser(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Could not save right now. Please try again.';

    final firstLine = raw.split('\n').first.trim();
    final sanitized = firstLine.replaceFirst(
      RegExp(
        r'^(Exception|FormatException|PlatformException|StateError|ArgumentError)\s*:?\s*',
      ),
      '',
    );
    if (sanitized.isEmpty ||
        sanitized.length > 140 ||
        sanitized.contains('/') ||
        sanitized.contains(r'\')) {
      return 'Could not save right now. Please try again.';
    }
    return 'Could not save: $sanitized';
  }
}
