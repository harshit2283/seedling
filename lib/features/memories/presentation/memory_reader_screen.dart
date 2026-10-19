import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/media/file_storage_service.dart';
import '../../../data/models/entry.dart';
import 'widgets/voice_player.dart';

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
    if (!PlatformUtils.isIOS) {
      final entry = widget.args.entries[_currentIndex];
      return Scaffold(
        appBar: AppBar(title: const Text('Memory')),
        body: Center(
          child: TextButton(
            onPressed: () => context.push(AppRoutes.entryRoute(entry.id)),
            child: const Text('Open memory details'),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF3F2EE),
      child: Stack(
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
              top: 54,
              left: 14,
              child: Semantics(
                button: true,
                label: 'Back',
                hint: 'Returns to memories',
                child: _frostedIconButton(
                  icon: CupertinoIcons.back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          if (_showChrome)
            Positioned(
              top: 54,
              right: 14,
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Switch reader style',
                    hint:
                        'Cycles between immersive, specimen, and poetic styles',
                    child: _frostedIconButton(
                      icon: _layoutIcon(),
                      onPressed: _cycleLayout,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: _showMetadata ? 'Hide metadata' : 'Show metadata',
                    child: _frostedIconButton(
                      icon: _showMetadata
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                      onPressed: () {
                        setState(() => _showMetadata = !_showMetadata);
                        _scheduleChromeHide();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Open details',
                    hint: 'Opens editable memory details',
                    child: _frostedIconButton(
                      icon: CupertinoIcons.ellipsis,
                      onPressed: () {
                        final entry = widget.args.entries[_currentIndex];
                        context.push(AppRoutes.entryRoute(entry.id));
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (_showChrome)
            Positioned(
              bottom: 34,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  label:
                      'Memory ${_currentIndex + 1} of ${widget.args.entries.length}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.args.entries.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(18, 112, 18, 90),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: switch (_layout) {
                    ReaderLayout.immersive => _buildImmersiveCard(
                      context,
                      entry,
                    ),
                    ReaderLayout.specimen => _buildSpecimenCard(
                      context,
                      entry,
                      resolvedMediaFuture,
                    ),
                    ReaderLayout.poetic => _buildPoeticCard(context, entry),
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

  Widget _buildImmersiveCard(BuildContext context, Entry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showMetadata) ...[
              _buildMetadataHeader(entry),
              const SizedBox(height: 12),
            ],
            Text(
              (entry.title ?? '').isNotEmpty ? entry.title! : entry.typeName,
              style: const TextStyle(
                color: SeedlingColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              entry.hasText
                  ? entry.text!
                  : 'A preserved moment from your living tree.',
              style: TextStyle(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.9),
                fontSize: 20,
                height: 1.7,
                fontStyle: entry.type == EntryType.release
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
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
        color: const Color(0xFFF9F8F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDAD7CC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              'SPECIMEN',
              style: TextStyle(
                color: SeedlingColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
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
            Text(
              (entry.title ?? '').isNotEmpty ? entry.title! : entry.typeName,
              style: const TextStyle(
                color: SeedlingColors.textPrimary,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.hasText
                  ? entry.text!
                  : 'A preserved moment from your living tree.',
              style: TextStyle(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.88),
                fontSize: 18,
                height: 1.65,
                fontStyle: entry.type == EntryType.release
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoeticCard(BuildContext context, Entry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 34),
        child: Column(
          children: [
            if (_showMetadata)
              Text(
                DateFormat('MMMM d').format(entry.createdAt),
                style: const TextStyle(
                  color: SeedlingColors.textSecondary,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              (entry.title ?? '').isNotEmpty ? entry.title! : entry.typeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SeedlingColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              entry.hasText
                  ? entry.text!
                  : 'A preserved moment from your living tree.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.85),
                fontSize: 21,
                height: 1.8,
                fontStyle: entry.type == EntryType.release
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataHeader(Entry entry) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.typeName.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: SeedlingColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('MMMM d, y').format(entry.createdAt),
          style: const TextStyle(
            color: SeedlingColors.textSecondary,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _frostedIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: CupertinoButton(
          padding: const EdgeInsets.all(10),
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          onPressed: onPressed,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
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
          final cacheWidth = MediaQuery.of(context).size.width.toInt();
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
                child: Container(color: Colors.black.withValues(alpha: 0.24)),
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
                child: const CupertinoActivityIndicator(),
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
                    child: const Icon(CupertinoIcons.photo),
                  )
                : Image.file(
                    File(resolvedPath),
                    fit: BoxFit.cover,
                    cacheWidth: MediaQuery.of(context).size.width.toInt(),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).dividerColor,
                      alignment: Alignment.center,
                      child: const Icon(CupertinoIcons.photo),
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
            child: const Center(child: CupertinoActivityIndicator()),
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
                const Icon(
                  CupertinoIcons.waveform,
                  color: SeedlingColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voice memo unavailable',
                    style: TextStyle(
                      color: SeedlingColors.textSecondary.withValues(
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
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _scheduleChromeHide();
  }

  void _goToNext() {
    if (_currentIndex >= widget.args.entries.length - 1) return;
    HapticFeedback.selectionClick();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
      setState(() => _showChrome = false);
    });
  }
}
