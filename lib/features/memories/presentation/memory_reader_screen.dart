import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../data/models/entry.dart';
import 'entry_detail_screen.dart' show keepsakeDateLine, yearsAgoLabel;
import 'widgets/keepsake_memory_card.dart'
    show keepsakeSerif, keepsakeSerifFallback;
import 'widgets/voice_player.dart';
import '../../../core/util/date_labels.dart';

class MemoryReaderArgs {
  final List<Entry> entries;
  final int initialIndex;

  const MemoryReaderArgs({required this.entries, required this.initialIndex});
}

enum ReaderLayout { immersive, specimen, poetic }

class MemoryReaderScreen extends StatefulWidget {
  final MemoryReaderArgs args;

  const MemoryReaderScreen({super.key, required this.args});

  @override
  State<MemoryReaderScreen> createState() => _MemoryReaderScreenState();
}

class _MemoryReaderScreenState extends State<MemoryReaderScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showChrome = true;
  bool _showMetadata = true;
  ReaderLayout _layout = ReaderLayout.immersive;
  Timer? _chromeTimer;
  final Map<String, Future<String?>> _resolvedMediaFutures = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MemoryReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validKeys = widget.args.entries
        .where((entry) => entry.mediaPath != null)
        .map(_mediaCacheKey)
        .toSet();
    _resolvedMediaFutures.removeWhere((key, value) => !validKeys.contains(key));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isIOS = PlatformUtils.isIOS;

    final body = Stack(
      children: [
        Semantics(
          label:
              'Memory reader. Tap left for previous, right for next, center for controls.',
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handleReaderTap(context, details),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.args.entries.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                HapticFeedback.selectionClick();
                _scheduleChromeHide();
              },
              itemBuilder: (context, index) =>
                  _buildEntryPage(context, widget.args.entries[index]),
            ),
          ),
        ),
        if (_showChrome)
          Positioned(
            top: topInset + 8,
            left: 14,
            child: _frostedIconButton(
              icon: isIOS ? CupertinoIcons.back : Icons.arrow_back,
              label: 'Back',
              hint: 'Returns to memories',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        if (_showChrome)
          Positioned(
            top: topInset + 8,
            right: 14,
            child: Row(
              children: [
                _frostedIconButton(
                  icon: _layoutIcon(),
                  label: 'Switch reader style',
                  hint: 'Cycles between immersive, pressed, and poetic styles',
                  onPressed: _cycleLayout,
                ),
                const SizedBox(width: 8),
                _frostedIconButton(
                  icon: _showMetadata
                      ? (isIOS
                            ? CupertinoIcons.eye_slash
                            : Icons.visibility_off_outlined)
                      : (isIOS
                            ? CupertinoIcons.eye
                            : Icons.visibility_outlined),
                  label: _showMetadata ? 'Hide details' : 'Show details',
                  onPressed: () {
                    setState(() => _showMetadata = !_showMetadata);
                    _scheduleChromeHide();
                  },
                ),
                const SizedBox(width: 8),
                _frostedIconButton(
                  icon: isIOS ? CupertinoIcons.ellipsis : Icons.more_horiz,
                  label: 'Open details',
                  hint: 'Opens editable memory details',
                  onPressed: () {
                    final entry = widget.args.entries[_currentIndex];
                    context.push(AppRoutes.entryRoute(entry.id));
                  },
                ),
              ],
            ),
          ),
        if (_showChrome)
          Positioned(
            bottom: bottomInset + 20,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label:
                    'Memory ${_currentIndex + 1} of ${widget.args.entries.length}',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.mediaScrim.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.onMedia.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.args.entries.length}',
                    style: TextStyle(
                      color: palette.onMedia,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: palette.background,
        child: body,
      );
    }
    return Scaffold(backgroundColor: palette.background, body: body);
  }

  Widget _buildEntryPage(BuildContext context, Entry entry) {
    final resolvedMediaFuture = _resolvedMediaFutureFor(entry);
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackdrop(entry, resolvedMediaFuture),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                _hasPhoto(entry) ? 76 : 112,
                18,
                90,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: switch (_layout) {
                    ReaderLayout.immersive => _buildImmersiveCard(
                      context,
                      entry,
                      resolvedMediaFuture,
                    ),
                    ReaderLayout.specimen => _buildSpecimenCard(
                      context,
                      entry,
                      resolvedMediaFuture,
                    ),
                    ReaderLayout.poetic => _buildPoeticCard(
                      context,
                      entry,
                      resolvedMediaFuture,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?>? _resolvedMediaFutureFor(Entry entry) {
    if (entry.mediaPath == null) return null;
    final key = _mediaCacheKey(entry);
    return _resolvedMediaFutures.putIfAbsent(
      key,
      () => FileStorageService.resolveMediaPath(entry.mediaPath),
    );
  }

  String _mediaCacheKey(Entry entry) => '${entry.id}:${entry.mediaPath ?? ''}';

  bool _hasPhoto(Entry entry) =>
      entry.hasMedia &&
      (entry.type == EntryType.photo || entry.type == EntryType.object);

  bool _hasTitle(Entry entry) => (entry.title ?? '').isNotEmpty;

  /// The heading for a page: the memory's own title, or its date when it
  /// has none. Never the entry type.
  String _heading(Entry entry) => _hasTitle(entry)
      ? entry.title!
      : DateFormat('d MMMM y', _locale).format(entry.createdAt);

  /// The quiet line above the heading: the date when the title leads,
  /// otherwise the time (and "2 years ago" for older memories).
  String _kicker(Entry entry) {
    if (_hasTitle(entry)) {
      return keepsakeDateLine(entry.createdAt, locale: _locale);
    }
    return [
      DateFormat.EEEE(_locale).format(entry.createdAt),
      DateLabels.timeOf(context, entry.createdAt),
      ?yearsAgoLabel(entry.createdAt, DateTime.now()),
    ].join('  ·  ');
  }

  String? get _locale => Localizations.maybeLocaleOf(context)?.toLanguageTag();

  /// The memory's words, or null when there are none to show. A wordless
  /// fragment says so; a photo without words lets the photo speak.
  String? _body(Entry entry) {
    if (entry.hasText) return entry.text!;
    if (entry.type == EntryType.fragment && !entry.hasMedia) {
      return 'A wordless fragment.';
    }
    return null;
  }

  TextStyle _serif(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.25,
    FontStyle style = FontStyle.normal,
  }) => TextStyle(
    fontFamily: keepsakeSerif,
    fontFamilyFallback: keepsakeSerifFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    fontStyle: style,
    color: color,
  );

  Widget _buildImmersiveCard(
    BuildContext context,
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    final palette = context.palette;
    final body = _body(entry);
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showMetadata) ...[
              Text(
                _kicker(entry),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Semantics(
              header: true,
              child: Text(
                _heading(entry),
                style: _serif(
                  _hasTitle(entry) ? 30 : 26,
                  weight: _hasTitle(entry) ? FontWeight.w600 : FontWeight.w400,
                  height: 1.18,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (entry.type == EntryType.voice && entry.mediaPath != null) ...[
              const SizedBox(height: 18),
              _buildResolvedVoicePlayer(entry, resolvedMediaFuture),
            ],
            if (body != null) ...[
              const SizedBox(height: 16),
              Text(
                body,
                style: _serif(
                  20,
                  height: 1.65,
                  style: entry.type == EntryType.release || !entry.hasText
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: palette.textPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!_hasPhoto(entry)) return card;

    // Photo memories lead with the photo itself, framed like a print.
    return Column(
      children: [
        _buildFramedPhoto(context, entry, resolvedMediaFuture),
        const SizedBox(height: 18),
        card,
      ],
    );
  }

  Widget _buildFramedPhoto(
    BuildContext context,
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    final palette = context.palette;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Container(
      width: double.infinity,
      height: maxHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.mediaScrim.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.expand(
          child: FutureBuilder<String?>(
            future: resolvedMediaFuture,
            builder: (context, snapshot) {
              final path = snapshot.data;
              if (path == null) {
                return ColoredBox(
                  color: palette.mediaScrim.withValues(alpha: 0.2),
                );
              }
              return Semantics(
                image: true,
                label: entry.title != null ? '${entry.title} photo' : 'Photo',
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: palette.mediaScrim.withValues(alpha: 0.2),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSpecimenCard(
    BuildContext context,
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    final hasMediaImage =
        entry.hasMedia &&
        entry.mediaPath != null &&
        (entry.type == EntryType.photo || entry.type == EntryType.object);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.border),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pressed between pages',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (_showMetadata) ...[
              const SizedBox(height: 8),
              _buildMetadataHeader(entry),
            ],
            if (entry.type == EntryType.voice && entry.mediaPath != null) ...[
              const SizedBox(height: 14),
              _buildResolvedVoicePlayer(entry, resolvedMediaFuture),
            ],
            if (hasMediaImage) ...[
              const SizedBox(height: 14),
              _buildResolvedSpecimenImage(entry, resolvedMediaFuture),
            ],
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                _heading(entry),
                style: _serif(
                  _hasTitle(entry) ? 27 : 24,
                  weight: _hasTitle(entry) ? FontWeight.w600 : FontWeight.w400,
                  height: 1.2,
                  color: context.palette.textPrimary,
                ),
              ),
            ),
            if (_body(entry) != null) ...[
              const SizedBox(height: 12),
              Text(
                _body(entry)!,
                style: _serif(
                  18,
                  height: 1.65,
                  style: entry.type == EntryType.release || !entry.hasText
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: context.palette.textPrimary.withValues(alpha: 0.88),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPoeticCard(
    BuildContext context,
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    final palette = context.palette;
    final body = _body(entry);
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 34),
        child: Column(
          children: [
            if (_showMetadata) ...[
              Text(
                _kicker(entry),
                textAlign: TextAlign.center,
                style: _serif(
                  15,
                  style: FontStyle.italic,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Semantics(
              header: true,
              child: Text(
                _heading(entry),
                textAlign: TextAlign.center,
                style: _serif(
                  _hasTitle(entry) ? 32 : 26,
                  weight: _hasTitle(entry) ? FontWeight.w600 : FontWeight.w400,
                  height: 1.15,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 22),
              Text(
                body,
                textAlign: TextAlign.center,
                style: _serif(
                  21,
                  height: 1.8,
                  style: entry.type == EntryType.release || !entry.hasText
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: palette.textPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!_hasPhoto(entry)) return card;
    return Column(
      children: [
        _buildFramedPhoto(context, entry, resolvedMediaFuture),
        const SizedBox(height: 18),
        card,
      ],
    );
  }

  Widget _buildMetadataHeader(Entry entry) {
    return Text(
      _kicker(entry),
      style: TextStyle(
        color: context.palette.textSecondary,
        fontSize: 12.5,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Chrome button over the reader backdrop. Always at least 44x44pt so it
  /// is easy to hit, with a label for screen readers.
  Widget _frostedIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? hint,
  }) {
    final palette = context.palette;
    final button = PlatformUtils.isIOS
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            color: palette.onMedia.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(22),
            onPressed: onPressed,
            child: Icon(icon, size: 20, color: palette.onMedia),
          )
        : Material(
            color: palette.mediaScrim.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(icon, size: 22, color: palette.onMedia),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          );
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      excludeSemantics: true,
      child: PlatformUtils.isIOS
          ? ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: button,
              ),
            )
          : button,
    );
  }

  Widget _buildBackdrop(Entry entry, Future<String?>? resolvedMediaFuture) {
    if (entry.hasMedia &&
        entry.mediaPath != null &&
        (entry.type == EntryType.photo || entry.type == EntryType.object)) {
      return FutureBuilder<String?>(
        future: resolvedMediaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildGradientBackdrop(entry);
          }
          final resolvedPath = snapshot.data;
          if (resolvedPath == null) {
            return _buildGradientBackdrop(entry);
          }
          final cacheWidth =
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(resolvedPath),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: context.palette.mediaScrim.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildGradientBackdrop(entry);
  }

  Widget _buildGradientBackdrop(Entry entry) {
    final gradient = switch (entry.type) {
      EntryType.release => const [Color(0xFF7B8F72), Color(0xFF1F2B20)],
      EntryType.fragment => const [Color(0xFF9C8A6B), Color(0xFF2A2420)],
      EntryType.voice => const [Color(0xFF4F7C82), Color(0xFF1D2F33)],
      _ => const [Color(0xFF8FA96D), Color(0xFF1F3222)],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
    );
  }

  Widget _buildResolvedSpecimenImage(
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    return FutureBuilder<String?>(
      future: resolvedMediaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.25,
              child: Container(
                color: Theme.of(context).dividerColor,
                alignment: Alignment.center,
                child: const CircularProgressIndicator.adaptive(),
              ),
            ),
          );
        }
        final resolvedPath = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: resolvedPath == null
                ? Container(
                    color: Theme.of(context).dividerColor,
                    alignment: Alignment.center,
                    child: Icon(
                      PlatformUtils.isIOS
                          ? CupertinoIcons.photo
                          : Icons.photo_outlined,
                    ),
                  )
                : Image.file(
                    File(resolvedPath),
                    fit: BoxFit.cover,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).dividerColor,
                      alignment: Alignment.center,
                      child: Icon(
                        PlatformUtils.isIOS
                            ? CupertinoIcons.photo
                            : Icons.photo_outlined,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResolvedVoicePlayer(
    Entry entry,
    Future<String?>? resolvedMediaFuture,
  ) {
    return FutureBuilder<String?>(
      future: resolvedMediaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final resolvedPath = snapshot.data;
        if (resolvedPath == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  PlatformUtils.isIOS
                      ? CupertinoIcons.waveform
                      : Icons.graphic_eq,
                  color: context.palette.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voice memo unavailable',
                    style: TextStyle(
                      color: context.palette.textSecondary.withValues(
                        alpha: 0.9,
                      ),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return VoicePlayer(audioPath: resolvedPath);
      },
    );
  }

  IconData _layoutIcon() {
    if (!PlatformUtils.isIOS) {
      return switch (_layout) {
        ReaderLayout.immersive => Icons.grid_view,
        ReaderLayout.specimen => Icons.notes,
        ReaderLayout.poetic => Icons.auto_awesome_outlined,
      };
    }
    return switch (_layout) {
      ReaderLayout.immersive => CupertinoIcons.square_grid_2x2,
      ReaderLayout.specimen => CupertinoIcons.text_justify,
      ReaderLayout.poetic => CupertinoIcons.sparkles,
    };
  }

  void _cycleLayout() {
    HapticFeedback.selectionClick();
    setState(() {
      _layout = switch (_layout) {
        ReaderLayout.immersive => ReaderLayout.specimen,
        ReaderLayout.specimen => ReaderLayout.poetic,
        ReaderLayout.poetic => ReaderLayout.immersive,
      };
    });
    _scheduleChromeHide();
  }

  void _handleReaderTap(BuildContext context, TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    if (dx < width * 0.32) {
      _goToPrevious();
      return;
    }
    if (dx > width * 0.68) {
      _goToNext();
      return;
    }
    setState(() => _showChrome = !_showChrome);
    if (_showChrome) {
      _scheduleChromeHide();
    }
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(_currentIndex - 1);
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    _scheduleChromeHide();
  }

  void _goToNext() {
    if (_currentIndex >= widget.args.entries.length - 1) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(_currentIndex + 1);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    _scheduleChromeHide();
  }

  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    if (mounted && !_showChrome) {
      setState(() => _showChrome = true);
    } else {
      _showChrome = true;
    }
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // Keep controls reachable for screen-reader and switch users.
      if (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) return;
      setState(() => _showChrome = false);
    });
  }
}
