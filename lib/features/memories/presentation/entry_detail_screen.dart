import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/sync_id.dart';
import '../../../core/services/ai/models/memory_theme.dart';
import 'memories_filter_state.dart';
import 'widgets/keepsake_memory_card.dart';
import 'widgets/photo_viewer.dart';
import 'widgets/memory_share_sheet.dart';
import 'widgets/voice_player.dart';
import 'widgets/season_sprig.dart';
import 'widgets/similar_memories_section.dart';
import '../../../core/widgets/feedback/seedling_toast.dart';

/// Formats the keepsake date header, e.g. "Saturday, 12 October 2024".
///
/// The day, month and year are held together, so a narrow screen breaks the
/// line after the weekday rather than stranding the year.
String keepsakeDateLine(DateTime date, {String? locale}) {
  final weekday = DateFormat.EEEE(locale).format(date);
  final day = DateFormat('d MMMM y', locale).format(date);
  return '$weekday, ${day.replaceAll(' ', '\u00A0')}';
}

/// Whole years between [date] and [now] ("2 years ago" needs 2 full years).
int wholeYearsBetween(DateTime date, DateTime now) {
  var years = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    years -= 1;
  }
  return years < 0 ? 0 : years;
}

/// "A year ago" / "3 years ago", or null when less than a year has passed.
String? yearsAgoLabel(DateTime date, DateTime now) {
  final years = wholeYearsBetween(date, now);
  if (years < 1) return null;
  return years == 1 ? 'A year ago' : '$years years ago';
}

/// A single memory, laid out like a page from a keepsake book.
///
/// Photo and object memories open on their photo, edge to edge and under a
/// translucent bar. The date is the header; the words are set like a page.
/// Sections only appear when they have something in them.
class EntryDetailScreen extends ConsumerStatefulWidget {
  final int entryId;
  final bool embedded;

  /// Opened from "From your tree" as an on-this-day memory: shows a soft
  /// "2 years ago today" header and gives the photo more room.
  final bool onThisDay;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.embedded = false,
    this.onThisDay = false,
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isEditMode = false;
  bool _isTranscribing = false;
  late TextEditingController _textController;
  late TextEditingController _titleController;
  PageController? _pageController;
  int? _currentEntryId;
  late final AnimationController _hintFade;
  bool _hintScheduled = false;

  /// True once the page has scrolled past its photo (or date header), so the
  /// bar turns solid and shows a short date.
  bool _scrolledPastHeader = false;

  /// Resolved media paths, one future per stored path, so rebuilds never
  /// flash a spinner.
  final Map<String, Future<String?>> _mediaFutures = {};

  static bool _hintShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _titleController = TextEditingController();
    _currentEntryId = widget.entryId;
    _hintFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    _pageController?.dispose();
    _hintFade.dispose();
    super.dispose();
  }

  Future<String?> _resolveMedia(String? path) => _mediaFutures.putIfAbsent(
    path ?? '',
    () => FileStorageService.resolveMediaPath(path),
  );

  void _maybeShowSwipeHint(int pageCount) {
    if (_hintScheduled || _hintShownThisSession || pageCount <= 1) return;
    _hintScheduled = true;
    _hintShownThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _hintFade.forward();
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      await _hintFade.reverse();
    });
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
    final activeId = _currentEntryId ?? widget.entryId;

    // Look the memory up by id across every year, so resurfaced memories,
    // deep links, links and related memories from past years all open.
    final entry = ref.watch(entryByIdProvider(activeId));
    if (entry == null) return _buildNotFound(context);

    if (widget.embedded || widget.onThisDay) {
      return _buildDetailView(context, entry);
    }

    // Swipe between memories when this one is in the list the person came
    // from (filtered first, so swiping matches what they saw).
    final filtered = ref.watch(filteredEntriesProvider);
    List<Entry>? pages;
    if (filtered.any((e) => e.id == activeId)) {
      pages = filtered;
    } else {
      final current = ref.watch(entriesProvider);
      if (current.any((e) => e.id == activeId)) pages = current;
    }

    if (pages == null || pages.length <= 1) {
      return _buildDetailView(context, entry);
    }

    _pageController ??= PageController(
      initialPage: pages.indexWhere((e) => e.id == activeId),
    );
    _maybeShowSwipeHint(pages.length);
    return _buildDetailView(context, entry, pages: pages);
  }

  Widget _buildNotFound(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: PlatformUtils.isIOS
          ? CupertinoNavigationBar(
                  backgroundColor: palette.background,
                  border: null,
                )
                as PreferredSizeWidget
          : AppBar(
              backgroundColor: palette.background,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AdaptiveIcons.leaf, size: 40, color: palette.textMuted),
              const SizedBox(height: 16),
              Text(
                'Memory not found',
                textAlign: TextAlign.center,
                style: _serif(22, color: palette.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'It may have been deleted. Recently deleted memories can be '
                'restored from Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layout helpers
  // ---------------------------------------------------------------------------

  static TextStyle _serif(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.25,
    FontStyle style = FontStyle.normal,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: keepsakeSerif,
    fontFamilyFallback: keepsakeSerifFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    fontStyle: style,
    letterSpacing: letterSpacing,
    color: color,
  );

  bool _hasHero(Entry entry) =>
      (entry.type == EntryType.photo || entry.type == EntryType.object) &&
      entry.hasMedia;

  bool _isOnThisDay(Entry entry) {
    if (!widget.onThisDay || entry.id != widget.entryId) return false;
    final now = DateTime.now();
    return entry.createdAt.month == now.month &&
        entry.createdAt.day == now.day &&
        entry.createdAt.year < now.year;
  }

  double _heroHeight(BuildContext context, Entry entry) {
    final size = MediaQuery.sizeOf(context);
    if (_isOnThisDay(entry)) return (size.height * 0.62).roundToDouble();
    final h = size.height * 0.54;
    final w = size.width * 1.2;
    return (h < w ? h : w).roundToDouble();
  }

  /// Height of the status bar plus the toolbar the page scrolls under.
  double _barExtent(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).top +
      (PlatformUtils.isIOS ? 44 : kToolbarHeight);

  bool _onScroll(ScrollUpdateNotification n, Entry entry) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final threshold = _hasHero(entry)
        ? _heroHeight(context, entry) - _barExtent(context)
        : 72.0;
    final past = n.metrics.pixels > threshold;
    if (past != _scrolledPastHeader) {
      setState(() => _scrolledPastHeader = past);
    }
    return false;
  }

  Widget _buildDetailView(
    BuildContext context,
    Entry entry, {
    List<Entry>? pages,
  }) {
    final palette = context.palette;

    Widget body;
    if (pages != null && _pageController != null) {
      body = Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            physics: _isEditMode
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (index) {
              if (index >= 0 && index < pages.length) {
                setState(() {
                  _currentEntryId = pages[index].id;
                  _scrolledPastHeader = false;
                });
                HapticFeedback.selectionClick();
              }
            },
            itemBuilder: (context, index) => _buildPage(context, pages[index]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _hintFade,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: palette.textPrimary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '← swipe →',
                      style: TextStyle(
                        color: palette.onMedia,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      body = _buildPage(context, entry);
    }

    body = NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) => _onScroll(n, entry),
      child: body,
    );

    // Embedded mode (tablet split view): no bar, just the page.
    if (widget.embedded) {
      return ColoredBox(
        color: palette.background,
        child: SafeArea(child: body),
      );
    }

    final overMedia = _hasHero(entry) && !_scrolledPastHeader;
    final fg = overMedia
        ? palette.onMedia
        : (PlatformUtils.isIOS ? palette.primary : palette.textPrimary);
    final showBarTitle = _isEditMode || _scrolledPastHeader;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final barTitle = _isEditMode
        ? 'Editing'
        : DateFormat.yMMMd(locale).format(entry.createdAt);
    final barColor = overMedia
        ? palette.background.withValues(alpha: 0)
        : palette.background.withValues(alpha: _scrolledPastHeader ? 0.86 : 0);
    final overlayStyle = overMedia || palette.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    final title = AnimatedOpacity(
      opacity: showBarTitle ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: Text(
        barTitle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: overMedia ? palette.onMedia : palette.textPrimary,
        ),
      ),
    );

    if (PlatformUtils.isIOS) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: CupertinoTheme(
          data: CupertinoTheme.of(context).copyWith(primaryColor: fg),
          child: CupertinoPageScaffold(
            backgroundColor: palette.background,
            navigationBar: CupertinoNavigationBar(
              automaticBackgroundVisibility: false,
              backgroundColor: barColor,
              border: _scrolledPastHeader
                  ? Border(
                      bottom: BorderSide(color: palette.divider, width: 0.5),
                    )
                  : null,
              middle: title,
              leading: _isEditMode
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _exitEditMode,
                      child: Text('Cancel', style: TextStyle(color: fg)),
                    )
                  : null,
              trailing: _buildTrailingActions(context, entry, fg),
            ),
            child: body,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: title,
        backgroundColor: barColor,
        foregroundColor: fg,
        iconTheme: IconThemeData(color: fg),
        actionsIconTheme: IconThemeData(color: fg),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        notificationPredicate: (_) => false,
        systemOverlayStyle: overlayStyle,
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: _exitEditMode,
              )
            : null,
        actions: _buildMaterialActions(context, entry, fg),
      ),
      body: body,
    );
  }

  Widget _buildTrailingActions(BuildContext context, Entry entry, Color fg) {
    if (_isEditMode) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _saveChanges(entry),
        child: Text(
          'Save',
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      );
    }

    Widget action(String label, IconData icon, VoidCallback onPressed) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(40, 44),
          onPressed: onPressed,
          child: Icon(icon, color: fg, size: 22),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        action(
          'Share memory',
          CupertinoIcons.share,
          () => showMemoryShareSheet(context, entry),
        ),
        if (_canEdit(entry))
          action(
            'Edit memory',
            CupertinoIcons.pencil,
            () => _enterEditMode(entry),
          ),
        action(
          'Delete memory',
          CupertinoIcons.trash,
          () => _confirmDelete(context, entry),
        ),
      ],
    );
  }

  List<Widget> _buildMaterialActions(
    BuildContext context,
    Entry entry,
    Color fg,
  ) {
    if (_isEditMode) {
      return [
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Save',
          color: fg,
          onPressed: () => _saveChanges(entry),
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.share_outlined),
        color: fg,
        tooltip: 'Share',
        onPressed: () => showMemoryShareSheet(context, entry),
      ),
      if (_canEdit(entry))
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          color: fg,
          tooltip: 'Edit memory',
          onPressed: () => _enterEditMode(entry),
        ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        color: fg,
        tooltip: 'Delete memory',
        onPressed: () => _confirmDelete(context, entry),
      ),
      const SizedBox(width: 4),
    ];
  }

  /// Check if entry has editable content (text or title)
  bool _canEdit(Entry entry) {
    // All types except voice-only can have their text edited
    // Objects always have a title that can be edited
    return entry.type != EntryType.voice || entry.hasText;
  }

  // ---------------------------------------------------------------------------
  // The page
  // ---------------------------------------------------------------------------

  Widget _buildPage(BuildContext context, Entry entry) {
    final palette = context.palette;
    final hero = _hasHero(entry);
    // The page scrolls under the bar, so leave room for it (none when
    // embedded in the split view, which has no bar).
    final topInset = widget.embedded ? 0.0 : _barExtent(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasTitle = entry.title != null && entry.title!.isNotEmpty;
    final editsTitle =
        _isEditMode &&
        (hasTitle ||
            entry.type == EntryType.object ||
            entry.type == EntryType.ritual);
    const gutter = 24.0;

    final words = <Widget>[
      // Without a photo, a small seasonal sprig gives the page its moment.
      if (!hero && !_isEditMode && !_isOnThisDay(entry)) ...[
        SeasonSprigHeader(date: entry.createdAt),
        const SizedBox(height: 14),
      ],
      if (_isOnThisDay(entry)) ...[
        _buildOnThisDayKicker(context, entry),
        const SizedBox(height: 10),
      ],
      _buildDateHeader(context, entry),
      if (editsTitle) ...[
        const SizedBox(height: 20),
        _buildEditableTitle(context, entry),
      ] else if (hasTitle) ...[
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            entry.title!,
            style: _serif(
              30,
              weight: FontWeight.w600,
              height: 1.18,
              letterSpacing: -0.2,
              color: palette.textPrimary,
            ),
          ),
        ),
      ],
      if (entry.type == EntryType.voice && entry.hasMedia) ...[
        const SizedBox(height: 24),
        _buildVoiceBlock(context, entry),
      ],
      if (_isEditMode && entry.type != EntryType.voice) ...[
        const SizedBox(height: 20),
        _buildEditableText(context, entry),
      ] else if (entry.hasText) ...[
        SizedBox(height: hasTitle ? 16 : 22),
        _buildTextContent(context, entry),
      ] else if (!entry.hasMedia && entry.type == EntryType.fragment) ...[
        const SizedBox(height: 22),
        Text(
          'A wordless fragment.',
          style: _serif(
            18,
            style: FontStyle.italic,
            color: palette.textSecondary,
          ),
        ),
      ],
      if (!_isEditMode) ..._buildQuietMetadata(context, entry),
    ];

    final hasLinks = entry.hasManualLinks;
    final linked = hasLinks && !_isEditMode
        ? ref.watch(linkedEntriesProvider(entry.manualLinkIds ?? ''))
        : const <Entry>[];

    return SingleChildScrollView(
      key: PageStorageKey('entry-page-${entry.id}'),
      padding: EdgeInsets.only(bottom: bottomInset + 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hero)
            _buildHero(context, entry)
          else
            SizedBox(height: topInset + 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      hero ? 4 : 8,
                      gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: words,
                    ),
                  ),
                  if (!_isEditMode)
                    SimilarMemoriesSection(
                      entryId: entry.id,
                      horizontalPadding: gutter,
                    ),
                  if (linked.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: KeepsakeSectionLabel('Linked memories'),
                    ),
                    const SizedBox(height: 12),
                    KeepsakeMemoryRow(
                      entries: linked,
                      semanticHint: 'Opens this memory. Hold to unlink.',
                      onOpen: (other) => _openMemory(context, other),
                      onLongPress: (other) =>
                          _confirmUnlink(context, entry, other),
                    ),
                  ],
                  if (!_isEditMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        gutter - 8,
                        28,
                        gutter,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildLinkAction(context, entry),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnThisDayKicker(BuildContext context, Entry entry) {
    final palette = context.palette;
    final years = DateTime.now().year - entry.createdAt.year;
    final label = years == 1 ? 'A year ago today' : '$years years ago today';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AdaptiveIcons.leaf, size: 16, color: palette.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: _serif(
            17,
            style: FontStyle.italic,
            color: palette.inkFor(palette.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(BuildContext context, Entry entry) {
    final palette = context.palette;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final date = entry.createdAt;
    final parts = <String>[
      DateFormat.jm(locale).format(date),
      if (!_isOnThisDay(entry)) ?yearsAgoLabel(date, DateTime.now()),
    ];
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keepsakeDateLine(date, locale: locale),
            style: _serif(
              entry.title?.isNotEmpty == true ? 21 : 25,
              height: 1.2,
              color: entry.title?.isNotEmpty == true
                  ? palette.textSecondary
                  : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            parts.join('  ·  '),
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 0.2,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, Entry entry) {
    final palette = context.palette;
    final height = _heroHeight(context, entry);
    final topScrim = _barExtent(context) + 48;

    Widget fallback({required bool missing}) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              palette.mediaScrim.withValues(alpha: 0.35),
              typeAccent(palette, entry.type),
            ),
            typeAccent(palette, entry.type).withValues(alpha: 0.5),
          ],
        ),
      ),
      child: missing
          ? Center(
              child: Text(
                'This photo is no longer on this device',
                style: TextStyle(color: palette.onMedia, fontSize: 14),
              ),
            )
          : const SizedBox.expand(),
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: _resolveMedia(entry.mediaPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return fallback(missing: false);
              }
              final resolvedPath = snapshot.data;
              if (resolvedPath == null) return fallback(missing: true);
              final label = entry.title != null
                  ? '${entry.title} photo.'
                  : 'Photo.';
              return Semantics(
                button: !_isEditMode,
                image: true,
                label: label,
                hint: _isEditMode ? null : 'Opens the photo full screen',
                child: GestureDetector(
                  onTap: _isEditMode
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => PhotoViewer(
                                imagePath: resolvedPath,
                                title: entry.title,
                              ),
                            ),
                          );
                        },
                  child: Hero(
                    tag: 'entry-${entry.id}',
                    transitionOnUserGestures: true,
                    child: Image.file(
                      File(resolvedPath),
                      width: double.infinity,
                      height: height,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Decode at display width instead of full camera size.
                      cacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      errorBuilder: (context, error, stackTrace) =>
                          fallback(missing: true),
                    ),
                  ),
                ),
              );
            },
          ),
          // A gentle scrim so the bar's icons stay readable on any photo.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topScrim,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.mediaScrim.withValues(alpha: 0.42),
                      palette.mediaScrim.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The photo settles into the page instead of ending on a hard edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: 49,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.background.withValues(alpha: 0),
                      palette.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(BuildContext context, Entry entry) {
    final palette = context.palette;
    final isRelease = entry.type == EntryType.release;
    return Text(
      entry.text!,
      style: _serif(
        19,
        height: 1.65,
        style: isRelease ? FontStyle.italic : FontStyle.normal,
        color: isRelease ? palette.textSecondary : palette.textPrimary,
      ),
    );
  }

  Widget _buildVoiceBlock(BuildContext context, Entry entry) {
    final palette = context.palette;
    return FutureBuilder<String?>(
      future: _resolveMedia(entry.mediaPath),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState != ConnectionState.done;
        final resolvedPath = snapshot.data;
        final hasTranscription =
            entry.transcription != null && entry.transcription!.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting)
              const SizedBox(height: 92)
            else if (resolvedPath != null)
              VoicePlayer(audioPath: resolvedPath)
            else
              Text(
                'This voice memo is no longer on this device.',
                style: _serif(
                  16,
                  style: FontStyle.italic,
                  color: palette.textMuted,
                ),
              ),
            if (!waiting && (resolvedPath != null || hasTranscription))
              _buildTranscriptionSection(context, entry),
          ],
        );
      },
    );
  }

  List<Widget> _buildQuietMetadata(BuildContext context, Entry entry) {
    final palette = context.palette;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final chips = <Widget>[];

    final theme = MemoryThemeExtension.fromString(entry.detectedTheme);
    if (theme != null) {
      final color = palette.themeColor(theme.name);
      chips.add(
        _MetaChip(
          leading: Text(theme.emoji, style: const TextStyle(fontSize: 13)),
          label: theme.displayName,
          fill: color.withValues(alpha: palette.isDark ? 0.22 : 0.14),
          ink: palette.inkFor(color),
        ),
      );
    }

    final place = entry.context?.trim();
    if (place != null && place.isNotEmpty) {
      chips.add(
        _MetaChip(
          leading: Icon(
            PlatformUtils.isIOS
                ? CupertinoIcons.location
                : Icons.place_outlined,
            size: 14,
            color: palette.textSecondary,
          ),
          label: place,
          ink: palette.textSecondary,
        ),
      );
    }

    final mood = entry.mood?.trim();
    if (mood != null && mood.isNotEmpty) {
      chips.add(_MetaChip(label: mood, ink: palette.textSecondary));
    }

    if (entry.isCapsule && entry.capsuleUnlockDate != null) {
      final fmt = DateFormat.yMMMd(locale);
      chips.add(
        _MetaChip(
          leading: Icon(
            PlatformUtils.isIOS
                ? CupertinoIcons.envelope_open
                : Icons.drafts_outlined,
            size: 14,
            color: palette.textSecondary,
          ),
          label:
              'Sealed ${fmt.format(entry.createdAt)}, opened '
              '${fmt.format(entry.capsuleUnlockDate!.toLocal())}',
          ink: palette.textSecondary,
        ),
      );
    }

    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      Wrap(spacing: 8, runSpacing: 8, children: chips),
    ];
  }

  Widget _buildLinkAction(BuildContext context, Entry entry) {
    final palette = context.palette;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PlatformUtils.isIOS ? CupertinoIcons.link : Icons.link,
          size: 16,
          color: palette.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          'Link a memory',
          style: TextStyle(fontSize: 15, color: palette.textSecondary),
        ),
      ],
    );
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(44, 44),
        onPressed: () => _showLinkPicker(context, entry),
        child: content,
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 48),
      ),
      onPressed: () => _showLinkPicker(context, entry),
      child: content,
    );
  }

  void _openMemory(BuildContext context, Entry other) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.entryRoute(other.id));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EntryDetailScreen(entryId: other.id),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Manual Linking
  // ---------------------------------------------------------------------------

  void _confirmUnlink(BuildContext context, Entry current, Entry linked) {
    HapticFeedback.selectionClick();

    if (PlatformUtils.isIOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Remove link?'),
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
          title: const Text('Remove link?'),
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
                style: TextStyle(color: context.palette.error),
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

    // Ensure both have syncUUIDs before proceeding
    final currentUUID = _ensureSyncUUID(current);
    final linkedUUID = _ensureSyncUUID(linked);

    // Remove linked's UUID from current's manualLinkIds
    final currentLinks = List<String>.from(current.manualLinkList)
      ..remove(linkedUUID);
    current.manualLinkIds = currentLinks.isEmpty
        ? null
        : currentLinks.join(',');
    _updateAndSync(current);

    // Remove current's UUID from linked's manualLinkIds
    final linkedLinks = List<String>.from(linked.manualLinkList)
      ..remove(currentUUID);
    linked.manualLinkIds = linkedLinks.isEmpty ? null : linkedLinks.join(',');
    _updateAndSync(linked);
  }

  void _showLinkPicker(BuildContext context, Entry current) {
    HapticFeedback.selectionClick();
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

    // Ensure both entries have a syncUUID
    final currentUUID = _ensureSyncUUID(current);
    final otherUUID = _ensureSyncUUID(other);

    // Add otherUUID to current's manualLinkIds (avoid duplicates)
    final currentLinks = List<String>.from(current.manualLinkList);
    if (!currentLinks.contains(otherUUID)) {
      currentLinks.add(otherUUID);
    }
    current.manualLinkIds = currentLinks.join(',');
    _updateAndSync(current);

    // Add currentUUID to other's manualLinkIds (bidirectional, avoid duplicates)
    final otherLinks = List<String>.from(other.manualLinkList);
    if (!otherLinks.contains(currentUUID)) {
      otherLinks.add(currentUUID);
    }
    other.manualLinkIds = otherLinks.join(',');
    _updateAndSync(other);
  }

  /// Saves [entry] and queues it for sync, so links and transcriptions reach
  /// the user's other devices.
  void _updateAndSync(Entry entry) {
    ref.read(entryCreatorProvider.notifier).saveEdit(entry);
  }

  /// Returns the existing syncUUID or generates and assigns a new one.
  /// Uses the same generator as the database and sync, so the id is never
  /// replaced later (which would break the link).
  String _ensureSyncUUID(Entry entry) {
    if (entry.syncUUID != null && entry.syncUUID!.isNotEmpty) {
      return entry.syncUUID!;
    }
    final newUUID = SyncId.generate();
    entry.syncUUID = newUUID;
    return newUUID;
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  BoxDecoration _fieldDecoration(BuildContext context) => BoxDecoration(
    color: context.palette.surfaceMuted.withValues(alpha: 0.6),
    borderRadius: SeedlingRadius.small,
    border: Border.all(color: context.palette.divider),
  );

  Widget _buildEditableTitle(BuildContext context, Entry entry) {
    final palette = context.palette;
    final style = _serif(
      26,
      weight: FontWeight.w600,
      height: 1.2,
      color: palette.textPrimary,
    );
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _titleController,
        placeholder: 'Title',
        style: style,
        decoration: _fieldDecoration(context),
        padding: const EdgeInsets.all(14),
      );
    }

    return TextField(
      controller: _titleController,
      style: style,
      decoration: InputDecoration(
        hintText: 'Title',
        filled: true,
        fillColor: palette.surfaceMuted.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: SeedlingRadius.small,
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SeedlingRadius.small,
          borderSide: BorderSide(color: palette.divider),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _buildEditableText(BuildContext context, Entry entry) {
    final palette = context.palette;
    final isRelease = entry.type == EntryType.release;
    final hintText = isRelease
        ? 'What are you letting go of?'
        : 'Add a few words…';
    final style = _serif(
      19,
      height: 1.65,
      style: isRelease ? FontStyle.italic : FontStyle.normal,
      color: isRelease ? palette.textSecondary : palette.textPrimary,
    );

    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        placeholder: hintText,
        maxLines: null,
        minLines: 5,
        style: style,
        decoration: _fieldDecoration(context),
        padding: const EdgeInsets.all(14),
      );
    }

    return TextField(
      controller: _textController,
      maxLines: null,
      minLines: 5,
      style: style,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: palette.surfaceMuted.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: SeedlingRadius.small,
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SeedlingRadius.small,
          borderSide: BorderSide(color: palette.divider),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Voice transcription
  // ---------------------------------------------------------------------------

  Widget _buildTranscriptionSection(BuildContext context, Entry entry) {
    final palette = context.palette;
    final hasTranscription =
        entry.transcription != null && entry.transcription!.isNotEmpty;

    if (hasTranscription) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: palette.accentVoice.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          child: Text(
            entry.transcription!,
            style: _serif(
              17,
              height: 1.6,
              style: FontStyle.italic,
              color: palette.textSecondary,
            ),
          ),
        ),
      );
    }

    if (_isTranscribing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: PlatformUtils.isIOS
                  ? const CupertinoActivityIndicator(radius: 8)
                  : CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              'Listening…',
              style: TextStyle(fontSize: 14, color: palette.textSecondary),
            ),
          ],
        ),
      );
    }

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PlatformUtils.isIOS ? CupertinoIcons.text_bubble : Icons.text_fields,
          size: 16,
          color: palette.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          'Transcribe',
          style: TextStyle(fontSize: 15, color: palette.textSecondary),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: PlatformUtils.isIOS
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: () => _transcribeEntry(entry),
              child: label,
            )
          : TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => _transcribeEntry(entry),
              child: label,
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
        showSeedlingMessage(context, 'Voice memo is unavailable');
      }
      return;
    }

    final transcriptionService = ref.read(speechTranscriptionServiceProvider);

    final canTranscribe = await transcriptionService.prepareOnDevice();
    if (!canTranscribe) {
      if (mounted) {
        showSeedlingMessage(
          context,
          'On-device transcription is not available on this device',
        );
      }
      return;
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
          _updateAndSync(freshEntry);
        }
        HapticFeedback.lightImpact();
      } else {
        if (mounted) {
          showSeedlingMessage(context, 'No speech detected');
        }
      }
    } catch (e, st) {
      const ErrorReporter().report(
        e,
        stack: st,
        context: 'EntryDetail.transcribe',
      );
      if (mounted) {
        showSeedlingMessage(context, 'Transcription failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

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
                style: TextStyle(color: context.palette.error),
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
}

/// A small, quiet metadata chip (theme, place, mood, capsule dates).
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.ink,
    this.leading,
    this.fill,
  });

  final String label;
  final Color ink;
  final Widget? leading;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: fill == null ? Border.all(color: context.palette.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
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
  Timer? _queryDebounce;

  /// Lowercased displayContent per entry object, tagged with the string it
  /// came from. Cached entries are replaced (not mutated) on edit, and the
  /// identity check catches in-place changes, so this never goes stale.
  static final _lowerDisplay = Expando<(String, String)>();

  static String _lowerFor(Entry entry) {
    final source = entry.displayContent;
    final cached = _lowerDisplay[entry];
    if (cached != null && identical(cached.$1, source)) return cached.$2;
    final lower = source.toLowerCase();
    _lowerDisplay[entry] = (source, lower);
    return lower;
  }

  void _onQueryChanged(String value) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(allEntriesProvider);

    // Exclude self and already-linked entries
    final alreadyLinked = widget.current.manualLinkList.toSet();
    final q = _query.toLowerCase();
    final candidates = allEntries.where((e) {
      if (e.id == widget.current.id) return false;
      // Locked capsules stay sealed: don't show or search their content.
      if (e.isLocked) return false;
      if (e.syncUUID != null && alreadyLinked.contains(e.syncUUID)) {
        return false;
      }
      if (q.isEmpty) return true;
      return _lowerFor(e).contains(q);
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
                    onChanged: _onQueryChanged,
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
                color: context.palette.textMuted.withValues(alpha: 0.4),
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
              onChanged: _onQueryChanged,
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
            ).textTheme.bodyMedium?.copyWith(color: context.palette.textMuted),
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
