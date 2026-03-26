import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../data/models/entry.dart';
import 'widgets/photo_viewer.dart';
import 'widgets/memory_share_sheet.dart';
import 'widgets/voice_player.dart';
import 'widgets/similar_memories_section.dart';

/// Detail screen for viewing and editing a single memory entry
class EntryDetailScreen extends ConsumerStatefulWidget {
  final int entryId;
  final bool embedded;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.embedded = false,
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  bool _isEditMode = false;
  bool _isTranscribing = false;
  late TextEditingController _textController;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _enterEditMode(Entry entry) {
    setState(() {
      _isEditMode = true;
      _textController.text = entry.text ?? '';
      _titleController.text = entry.title ?? '';
    });
    HapticFeedback.selectionClick();
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
    });
  }

  void _saveChanges(Entry entry) {
    HapticFeedback.lightImpact();

    final newText = _textController.text.trim();
    final newTitle = _titleController.text.trim();

    ref
        .read(entryCreatorProvider.notifier)
        .updateEntryText(
          entry.id,
          text: newText.isEmpty ? null : newText,
          title: newTitle.isEmpty ? null : newTitle,
        );

    _exitEditMode();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider);
    final entry = entries.where((e) => e.id == widget.entryId).firstOrNull;

    if (entry == null) {
      return _buildNotFound(context);
    }

    return _buildDetailView(context, entry);
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PlatformUtils.isIOS
          ? CupertinoNavigationBar(
                  middle: const Text('Memory'),
                  backgroundColor: Colors.transparent,
                )
                as PreferredSizeWidget
          : AppBar(
              title: const Text('Memory'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.doc_text_search
                  : Icons.search_off,
              size: 64,
              color: SeedlingColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Memory not found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(BuildContext context, Entry entry) {
    final typeColor = _getTypeColor(entry.type);

    // Embedded mode: no scaffold/nav bar, just the content body
    if (widget.embedded) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(child: _buildContent(context, entry, typeColor)),
      );
    }

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: Text(_isEditMode ? 'Edit ${entry.typeName}' : entry.typeName),
          backgroundColor: Colors.transparent,
          border: null,
          leading: _isEditMode
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _exitEditMode,
                  child: const Text('Cancel'),
                )
              : null,
          trailing: _buildTrailingActions(context, entry),
        ),
        child: SafeArea(child: _buildContent(context, entry, typeColor)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit ${entry.typeName}' : entry.typeName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitEditMode,
              )
            : null,
        actions: _buildMaterialActions(context, entry),
      ),
      body: _buildContent(context, entry, typeColor),
    );
  }

  Widget _buildTrailingActions(BuildContext context, Entry entry) {
    if (_isEditMode) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _saveChanges(entry),
        child: Text(
          'Save',
          style: TextStyle(
            color: SeedlingColors.forestGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Share memory',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => showMemoryShareSheet(context, entry),
            child: const Icon(
              CupertinoIcons.share,
              color: SeedlingColors.forestGreen,
              size: 22,
            ),
          ),
        ),
        if (_canEdit(entry))
          Semantics(
            button: true,
            label: 'Edit memory',
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _enterEditMode(entry),
              child: const Icon(
                CupertinoIcons.pencil,
                color: SeedlingColors.forestGreen,
                size: 22,
              ),
            ),
          ),
        Semantics(
          button: true,
          label: 'Delete memory',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _confirmDelete(context, entry),
            child: const Icon(
              CupertinoIcons.trash,
              color: SeedlingColors.error,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMaterialActions(BuildContext context, Entry entry) {
    if (_isEditMode) {
      return [
        IconButton(
          icon: const Icon(Icons.check),
          color: SeedlingColors.forestGreen,
          onPressed: () => _saveChanges(entry),
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.share_outlined),
        color: SeedlingColors.forestGreen,
        tooltip: 'Share',
        onPressed: () => showMemoryShareSheet(context, entry),
      ),
      if (_canEdit(entry))
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          color: SeedlingColors.forestGreen,
          onPressed: () => _enterEditMode(entry),
        ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        color: SeedlingColors.error,
        onPressed: () => _confirmDelete(context, entry),
      ),
    ];
  }

  /// Check if entry has editable content (text or title)
  bool _canEdit(Entry entry) {
    // All types except voice-only can have their text edited
    // Objects always have a title that can be edited
    return entry.type != EntryType.voice || entry.hasText;
  }

  Widget _buildContent(BuildContext context, Entry entry, Color typeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media content (not editable)
          if (entry.hasMedia) _buildMediaContent(context, entry),
          // Title (for objects) - editable
          if (_isEditMode &&
              (entry.type == EntryType.object ||
                  entry.type == EntryType.ritual)) ...[
            if (entry.hasMedia) const SizedBox(height: 20),
            _buildEditableTitle(context, entry),
          ] else if (entry.title != null && entry.title!.isNotEmpty) ...[
            if (entry.hasMedia) const SizedBox(height: 20),
            Text(
              entry.title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: SeedlingColors.textPrimary,
              ),
            ),
          ],
          // Text content - editable
          if (_isEditMode && entry.type != EntryType.voice) ...[
            const SizedBox(height: 16),
            _buildEditableText(context, entry),
          ] else if (entry.hasText) ...[
            const SizedBox(height: 16),
            _buildTextContent(context, entry),
          ],
          // Empty state for fragments
          if (!_isEditMode &&
              !entry.hasText &&
              !entry.hasMedia &&
              entry.type == EntryType.fragment) ...[
            _buildEmptyFragment(context),
          ],
          const SizedBox(height: 24),
          // Metadata
          _buildMetadata(context, entry, typeColor),
          // Similar memories section (only show when not in edit mode)
          if (!_isEditMode) SimilarMemoriesSection(entryId: entry.id),
          // Manually linked memories (only show when not in edit mode)
          if (!_isEditMode) _buildLinkedMemories(context, entry),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Manual Linking
  // ---------------------------------------------------------------------------

  Widget _buildLinkedMemories(BuildContext context, Entry entry) {
    // Watch entries stream so linked entries update when they change
    final db = ref.read(databaseProvider);
    ref.watch(entriesStreamProvider);
    final linkedEntries = db.getEntriesBySyncUUIDs(entry.manualLinkList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                PlatformUtils.isIOS ? CupertinoIcons.link : Icons.link,
                size: 18,
                color: SeedlingColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Linked',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal list of linked memories
        if (linkedEntries.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: linkedEntries.length,
              itemBuilder: (context, index) {
                return _buildLinkedMemoryCard(
                  context,
                  linkedEntries[index],
                  entry,
                  isFirst: index == 0,
                  isLast: index == linkedEntries.length - 1,
                );
              },
            ),
          ),
        // "Link a memory" button
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: PlatformUtils.isIOS
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showLinkPicker(context, entry),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.plus_circle,
                        size: 16,
                        color: SeedlingColors.forestGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Link a memory',
                        style: TextStyle(
                          fontSize: 14,
                          color: SeedlingColors.forestGreen,
                        ),
                      ),
                    ],
                  ),
                )
              : TextButton.icon(
                  onPressed: () => _showLinkPicker(context, entry),
                  icon: Icon(
                    Icons.add_link,
                    size: 16,
                    color: SeedlingColors.forestGreen,
                  ),
                  label: Text(
                    'Link a memory',
                    style: TextStyle(color: SeedlingColors.forestGreen),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLinkedMemoryCard(
    BuildContext context,
    Entry linked,
    Entry current, {
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: isFirst ? 0 : 8, right: isLast ? 0 : 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EntryDetailScreen(entryId: linked.id),
            ),
          );
        },
        onLongPress: () => _confirmUnlink(context, current, linked),
        child: _LinkedMemoryCardContent(entry: linked),
      ),
    );
  }

  void _confirmUnlink(BuildContext context, Entry current, Entry linked) {
    HapticFeedback.selectionClick();

    if (PlatformUtils.isIOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Remove Link?'),
          content: Text(
            'Remove the link between this memory and "${linked.displayContent}"?',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop();
                _unlinkEntries(current, linked);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Link?'),
          content: Text(
            'Remove the link between this memory and "${linked.displayContent}"?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Remove',
                style: TextStyle(color: SeedlingColors.error),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _unlinkEntries(current, linked);
              },
            ),
          ],
        ),
      );
    }
  }

  void _unlinkEntries(Entry current, Entry linked) {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);

    // Ensure both have syncUUIDs before proceeding
    final currentUUID = _ensureSyncUUID(current);
    final linkedUUID = _ensureSyncUUID(linked);

    // Remove linked's UUID from current's manualLinkIds
    final currentLinks = List<String>.from(current.manualLinkList)
      ..remove(linkedUUID);
    current.manualLinkIds = currentLinks.isEmpty
        ? null
        : currentLinks.join(',');
    db.updateEntry(current);

    // Remove current's UUID from linked's manualLinkIds
    final linkedLinks = List<String>.from(linked.manualLinkList)
      ..remove(currentUUID);
    linked.manualLinkIds = linkedLinks.isEmpty ? null : linkedLinks.join(',');
    db.updateEntry(linked);
  }

  void _showLinkPicker(BuildContext context, Entry current) {
    if (PlatformUtils.isIOS) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => _LinkPickerSheet(
          current: current,
          onLink: (other) => _linkEntries(current, other),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _LinkPickerSheet(
          current: current,
          onLink: (other) => _linkEntries(current, other),
        ),
      );
    }
  }

  void _linkEntries(Entry current, Entry other) {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);

    // Ensure both entries have a syncUUID
    final currentUUID = _ensureSyncUUID(current);
    final otherUUID = _ensureSyncUUID(other);

    // Save UUID if we just generated it
    if (current.syncUUID != currentUUID) {
      current.syncUUID = currentUUID;
    }
    if (other.syncUUID != otherUUID) {
      other.syncUUID = otherUUID;
    }

    // Add otherUUID to current's manualLinkIds (avoid duplicates)
    final currentLinks = List<String>.from(current.manualLinkList);
    if (!currentLinks.contains(otherUUID)) {
      currentLinks.add(otherUUID);
    }
    current.manualLinkIds = currentLinks.join(',');
    db.updateEntry(current);

    // Add currentUUID to other's manualLinkIds (bidirectional, avoid duplicates)
    final otherLinks = List<String>.from(other.manualLinkList);
    if (!otherLinks.contains(currentUUID)) {
      otherLinks.add(currentUUID);
    }
    other.manualLinkIds = otherLinks.join(',');
    db.updateEntry(other);
  }

  /// Returns the existing syncUUID or generates and assigns a new one
  String _ensureSyncUUID(Entry entry) {
    if (entry.syncUUID != null && entry.syncUUID!.isNotEmpty) {
      return entry.syncUUID!;
    }
    final newUUID = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    entry.syncUUID = newUUID;
    return newUUID;
  }

  Widget _buildEditableTitle(BuildContext context, Entry entry) {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _titleController,
        placeholder: 'Title',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: SeedlingColors.textPrimary,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
      );
    }

    return TextField(
      controller: _titleController,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: SeedlingColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Title',
        filled: true,
        fillColor: Theme.of(context).dividerColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildEditableText(BuildContext context, Entry entry) {
    final isRelease = entry.type == EntryType.release;
    final hintText = isRelease
        ? 'What are you letting go of?'
        : 'Add a note...';

    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        placeholder: hintText,
        maxLines: null,
        minLines: 4,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.6,
          color: isRelease
              ? SeedlingColors.textSecondary
              : SeedlingColors.textPrimary,
          fontStyle: isRelease ? FontStyle.italic : FontStyle.normal,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
      );
    }

    return TextField(
      controller: _textController,
      maxLines: null,
      minLines: 4,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.6,
        color: isRelease
            ? SeedlingColors.textSecondary
            : SeedlingColors.textPrimary,
        fontStyle: isRelease ? FontStyle.italic : FontStyle.normal,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Theme.of(context).dividerColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context, Entry entry) {
    switch (entry.type) {
      case EntryType.photo:
      case EntryType.object:
        if (entry.mediaPath != null) {
          return _buildPhotoContent(context, entry);
        }
        break;
      case EntryType.voice:
        if (entry.mediaPath != null) {
          return FutureBuilder<String?>(
            future: FileStorageService.resolveMediaPath(entry.mediaPath),
            builder: (context, snapshot) {
              final hasTranscription =
                  entry.transcription != null &&
                  entry.transcription!.isNotEmpty;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 56,
                      child: Center(
                        child: PlatformUtils.isIOS
                            ? const CupertinoActivityIndicator()
                            : const CircularProgressIndicator.adaptive(),
                      ),
                    ),
                    if (hasTranscription)
                      _buildTranscriptionSection(context, entry),
                  ],
                );
              }
              final resolvedPath = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resolvedPath != null)
                    VoicePlayer(audioPath: resolvedPath)
                  else
                    _buildUnavailableMediaMessage('Voice memo unavailable'),
                  if (resolvedPath != null || hasTranscription)
                    _buildTranscriptionSection(context, entry),
                ],
              );
            },
          );
        }
        break;
      default:
        break;
    }
    return const SizedBox.shrink();
  }

  Widget _buildPhotoContent(BuildContext context, Entry entry) {
    return FutureBuilder<String?>(
      future: FileStorageService.resolveMediaPath(entry.mediaPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 240,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: PlatformUtils.isIOS
                  ? const CupertinoActivityIndicator()
                  : const CircularProgressIndicator.adaptive(),
            ),
          );
        }

        final resolvedPath = snapshot.data;
        if (resolvedPath == null) {
          return _buildUnavailableMediaMessage('Photo unavailable');
        }
        final semanticsLabel = _isEditMode
            ? (entry.title != null ? '${entry.title} photo.' : 'Photo.')
            : (entry.title != null
                  ? '${entry.title} photo. Double tap to view full screen.'
                  : 'Photo. Double tap to view full screen.');
        return Semantics(
          button: !_isEditMode,
          label: semanticsLabel,
          child: GestureDetector(
            onTap: _isEditMode
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PhotoViewer(
                          imagePath: resolvedPath,
                          title: entry.title,
                        ),
                      ),
                    );
                  },
            child: Hero(
              tag: 'photo_${entry.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(resolvedPath),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildUnavailableMediaMessage('Photo unavailable'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnavailableMediaMessage(String label) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: SeedlingColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildTranscriptionSection(BuildContext context, Entry entry) {
    final hasTranscription =
        entry.transcription != null && entry.transcription!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTranscription) ...[
            GlassContainer(
              borderRadius: 12,
              opacity: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transcription',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SeedlingColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.transcription!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (!_isTranscribing)
              PlatformUtils.isIOS
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _transcribeEntry(entry),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.text_bubble,
                            size: 16,
                            color: SeedlingColors.forestGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Transcribe',
                            style: TextStyle(
                              fontSize: 14,
                              color: SeedlingColors.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () => _transcribeEntry(entry),
                      icon: Icon(
                        Icons.text_fields,
                        size: 16,
                        color: SeedlingColors.forestGreen,
                      ),
                      label: Text(
                        'Transcribe',
                        style: TextStyle(color: SeedlingColors.forestGreen),
                      ),
                    ),
            if (_isTranscribing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: PlatformUtils.isIOS
                          ? const CupertinoActivityIndicator(radius: 8)
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SeedlingColors.forestGreen,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transcribing...',
                      style: TextStyle(
                        fontSize: 14,
                        color: SeedlingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _transcribeEntry(Entry entry) async {
    if (entry.mediaPath == null) return;
    final resolvedPath = await FileStorageService.resolveMediaPath(
      entry.mediaPath,
    );
    if (resolvedPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice memo is unavailable')),
        );
      }
      return;
    }

    final transcriptionService = ref.read(speechTranscriptionServiceProvider);

    final isAvailable = await transcriptionService.isAvailable();
    if (!isAvailable) {
      // Try requesting permission first
      final granted = await transcriptionService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('On-device transcription is not available'),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isTranscribing = true);
    HapticFeedback.selectionClick();

    try {
      final result = await transcriptionService.transcribe(resolvedPath);
      if (result != null && result.isNotEmpty) {
        // Save transcription to entry
        final db = ref.read(databaseProvider);
        final freshEntry = db.getEntry(entry.id);
        if (freshEntry != null) {
          freshEntry.transcription = result.transcription;
          db.updateEntry(freshEntry);
        }
        HapticFeedback.lightImpact();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No speech detected')));
        }
      }
    } catch (e) {
      debugPrint('Entry detail operation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transcription failed')));
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  Widget _buildTextContent(BuildContext context, Entry entry) {
    final isRelease = entry.type == EntryType.release;

    return GlassContainer(
      borderRadius: 12,
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          entry.text!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: isRelease
                ? SeedlingColors.textSecondary
                : SeedlingColors.textPrimary,
            fontStyle: isRelease ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFragment(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SeedlingColors.accentFragment.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SeedlingColors.accentFragment.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.sparkles
                  : Icons.auto_awesome,
              color: SeedlingColors.accentFragment,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'A wordless fragment',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SeedlingColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Entry entry, Color typeColor) {
    return Row(
      children: [
        // Type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getTypeIcon(entry.type), color: typeColor, size: 16),
              const SizedBox(width: 6),
              Text(
                entry.typeName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Date
        Text(
          _formatDate(entry.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: SeedlingColors.textMuted),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Entry entry) {
    HapticFeedback.selectionClick();

    // Updated dialog message to reflect soft delete with recovery
    const title = 'Delete Memory?';
    const content =
        'This memory will be moved to trash and can be recovered within 30 days.';

    if (PlatformUtils.isIOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text(title),
          content: const Text(content),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEntry(context, entry);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(title),
          content: const Text(content),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Delete',
                style: TextStyle(color: SeedlingColors.error),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEntry(context, entry);
              },
            ),
          ],
        ),
      );
    }
  }

  void _deleteEntry(BuildContext context, Entry entry) {
    HapticFeedback.mediumImpact();
    ref.read(entryCreatorProvider.notifier).deleteEntry(entry.id);
    Navigator.of(context).pop();
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }

    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(entryDate).inDays;

    if (difference == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference < 7) {
      return '${DateFormat('EEEE').format(date)} at ${DateFormat('h:mm a').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }
}

// =============================================================================
// Linked Memory Card Content
// =============================================================================

class _LinkedMemoryCardContent extends StatelessWidget {
  final Entry entry;

  const _LinkedMemoryCardContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      opacity: 0.6,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeading(),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                entry.displayContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SeedlingColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hold to unlink',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SeedlingColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (entry.hasMedia &&
        (entry.type == EntryType.photo || entry.type == EntryType.object)) {
      return FutureBuilder<File?>(
        future: FileStorageService.resolveMediaFile(entry.mediaPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }
          final resolvedFile = snapshot.data;
          if (resolvedFile == null) {
            return _buildTypeIcon();
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              resolvedFile,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildTypeIcon(),
            ),
          );
        },
      );
    }
    return _buildTypeIcon();
  }

  Widget _buildTypeIcon() {
    final color = _getTypeColor(entry.type);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getTypeIcon(entry.type), color: color, size: 18),
    );
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }
    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }
}

// =============================================================================
// Link Picker Bottom Sheet
// =============================================================================

class _LinkPickerSheet extends ConsumerStatefulWidget {
  final Entry current;
  final void Function(Entry other) onLink;

  const _LinkPickerSheet({required this.current, required this.onLink});

  @override
  ConsumerState<_LinkPickerSheet> createState() => _LinkPickerSheetState();
}

class _LinkPickerSheetState extends ConsumerState<_LinkPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(allEntriesProvider);

    // Exclude self and already-linked entries
    final alreadyLinked = widget.current.manualLinkList.toSet();
    final candidates = allEntries.where((e) {
      if (e.id == widget.current.id) return false;
      if (e.syncUUID != null && alreadyLinked.contains(e.syncUUID)) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.displayContent.toLowerCase().contains(q);
    }).toList();

    if (PlatformUtils.isIOS) {
      return _buildIOSSheet(context, candidates);
    }
    return _buildMaterialSheet(context, candidates);
  }

  Widget _buildIOSSheet(BuildContext context, List<Entry> candidates) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: CupertinoPopupSurface(
        isSurfacePainted: false,
        child: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.darkColor.withValues(
                alpha: 0.6,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.separator,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Link a memory',
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navTitleTextStyle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search memories...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(child: _buildCandidateList(context, candidates)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialSheet(BuildContext context, List<Entry> candidates) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SeedlingColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Link a memory',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search memories...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).dividerColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _buildCandidateList(context, candidates)),
        ],
      ),
    );
  }

  Widget _buildCandidateList(BuildContext context, List<Entry> candidates) {
    if (candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.isEmpty
                ? 'No other memories to link'
                : 'No memories match your search',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: SeedlingColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final entry = candidates[index];
        return _buildCandidateTile(context, entry);
      },
    );
  }

  Widget _buildCandidateTile(BuildContext context, Entry entry) {
    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        leading: _buildEntryLeadingIcon(entry),
        title: Text(
          entry.displayContent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatShortDate(entry.createdAt),
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop();
          widget.onLink(entry);
        },
      );
    }

    return ListTile(
      leading: _buildEntryLeadingIcon(entry),
      title: Text(
        entry.displayContent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_formatShortDate(entry.createdAt)),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        widget.onLink(entry);
      },
    );
  }

  Widget _buildEntryLeadingIcon(Entry entry) {
    final color = _getTypeColor(entry.type);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getTypeIcon(entry.type), color: color, size: 18),
    );
  }

  String _formatShortDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    if (date.year == now.year) return DateFormat('MMM d').format(date);
    return DateFormat('MMM d, y').format(date);
  }

  IconData _getTypeIcon(EntryType type) {
    if (PlatformUtils.isIOS) {
      switch (type) {
        case EntryType.line:
          return CupertinoIcons.text_quote;
        case EntryType.photo:
          return CupertinoIcons.photo;
        case EntryType.voice:
          return CupertinoIcons.waveform;
        case EntryType.object:
          return CupertinoIcons.cube;
        case EntryType.fragment:
          return CupertinoIcons.sparkles;
        case EntryType.ritual:
          return CupertinoIcons.arrow_2_circlepath;
        case EntryType.release:
          return CupertinoIcons.wind;
      }
    }
    switch (type) {
      case EntryType.line:
        return Icons.format_quote;
      case EntryType.photo:
        return Icons.photo_outlined;
      case EntryType.voice:
        return Icons.graphic_eq;
      case EntryType.object:
        return Icons.category_outlined;
      case EntryType.fragment:
        return Icons.auto_awesome;
      case EntryType.ritual:
        return Icons.loop;
      case EntryType.release:
        return Icons.air;
    }
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.line:
        return SeedlingColors.accentLine;
      case EntryType.photo:
        return SeedlingColors.accentPhoto;
      case EntryType.voice:
        return SeedlingColors.accentVoice;
      case EntryType.object:
        return SeedlingColors.accentObject;
      case EntryType.fragment:
        return SeedlingColors.accentFragment;
      case EntryType.ritual:
        return SeedlingColors.accentRitual;
      case EntryType.release:
        return SeedlingColors.accentRelease;
    }
  }
}
