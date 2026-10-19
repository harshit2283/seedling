import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../app/theme/typography.dart';
import '../../../core/models/season.dart';
import '../../../core/services/providers.dart';
import '../../tree/presentation/painting/tree_illustration.dart';
import '../../../core/platform/platform_utils.dart';

/// Data model for a single onboarding panel.
class _OnboardingPanel {
  final String title;
  final String subtitle;

  /// How grown the tree is on this panel (see [TreeScene.growth]):
  /// seed, sprout, sapling, young tree.
  final double growth;

  /// The panel that asks for the person's own capture cue.
  final bool asksForIntention;

  const _OnboardingPanel({
    required this.title,
    required this.subtitle,
    required this.growth,
    this.asksForIntention = false,
  });
}

const _panels = [
  _OnboardingPanel(
    title: 'Welcome to Seedling',
    subtitle: 'A calm place to keep what mattered.',
    growth: 0.6,
  ),
  _OnboardingPanel(
    title: 'Every memory is a seed',
    subtitle:
        'Keep a line, a photo, a voice, a feeling. '
        'Each one helps your tree grow.',
    growth: 1.6,
  ),
  _OnboardingPanel(
    title: 'When do small moments find you?',
    subtitle:
        'Tie Seedling to something you already do. We\'ll keep it as a '
        'quiet hint, nothing more.',
    growth: 2.55,
    asksForIntention: true,
  ),
  _OnboardingPanel(
    title: 'Start with one memory',
    subtitle: 'No streaks, no counting. Your tree grows at your pace.',
    growth: 3.55,
  ),
];

/// The intention field's example. Short enough to never truncate.
const String onboardingIntentionHint = 'e.g. With my morning coffee';

/// Same seed every launch, so everyone meets the same young tree.
const int _onboardingTreeSeed = 2024;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _intentionController = TextEditingController();
  final FocusNode _intentionFocus = FocusNode();
  int _currentPage = 0;
  bool _completing = false;

  /// Animation controllers for each panel's fade-in.
  late final List<AnimationController> _fadeControllers;
  late final List<Animation<double>> _fadeAnimations;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _onLastPage => _currentPage == _panels.length - 1;

  @override
  void initState() {
    super.initState();

    _intentionController.text =
        ref.read(onboardingPreferencesProvider).captureIntention ?? '';

    _fadeControllers = List.generate(
      _panels.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _fadeAnimations = _fadeControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start the first panel's fade (or show it at once with reduced motion).
    final first = _fadeControllers[0];
    if (first.status == AnimationStatus.dismissed) {
      if (_reduceMotion) {
        first.value = 1;
      } else {
        first.forward();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _intentionController.dispose();
    _intentionFocus.dispose();
    for (final controller in _fadeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (_panels[_currentPage].asksForIntention) {
      _intentionFocus.unfocus();
      unawaited(_saveIntention());
    }
    setState(() {
      _currentPage = page;
    });
    // Trigger fade-in for the new panel.
    if (_reduceMotion) {
      _fadeControllers[page].value = 1;
    } else {
      _fadeControllers[page].forward(from: 0.0);
    }
  }

  void _goToPage(int page) {
    if (page == _currentPage || page < 0 || page >= _panels.length) return;
    HapticFeedback.selectionClick();
    if (_reduceMotion) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveIntention() {
    return ref
        .read(captureIntentionProvider.notifier)
        .set(_intentionController.text);
  }

  /// Finishes onboarding. With [openCapture] the home screen opens the
  /// capture sheet as soon as it appears, so the button keeps its promise.
  Future<void> _completeOnboarding({required bool openCapture}) async {
    if (_completing) return;
    _completing = true;
    await _saveIntention();
    final onboarding = ref.read(onboardingPreferencesProvider);
    await onboarding.setCompleted();
    if (openCapture) {
      ref.read(pendingFirstCaptureProvider.notifier).request();
    }
    if (mounted) {
      context.go('/');
    }
  }

  /// The page position the tree follows: the live scroll position while
  /// swiping, or the settled page when motion is reduced.
  double get _pagePosition {
    if (!_reduceMotion &&
        _pageController.hasClients &&
        _pageController.position.haveDimensions) {
      return _pageController.page ?? _currentPage.toDouble();
    }
    return _currentPage.toDouble();
  }

  double _growthAt(double page) {
    final p = page.clamp(0.0, _panels.length - 1.0);
    final lower = p.floor();
    final upper = p.ceil();
    final t = p - lower;
    return _panels[lower].growth +
        (_panels[upper].growth - _panels[lower].growth) * t;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: palette.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.backgroundGradientStart,
              palette.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip, always one tap away (the last page has its own quiet
              // "Not now").
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _onLastPage
                      ? const SizedBox.shrink()
                      : _QuietTextButton(
                          label: 'Skip',
                          color: palette.textSecondary,
                          onPressed: () =>
                              _completeOnboarding(openCapture: false),
                        ),
                ),
              ),
              // The tree, growing a stage with every page.
              if (!keyboardOpen)
                Expanded(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) =>
                          _OnboardingTree(growth: _growthAt(_pagePosition)),
                    ),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _panels.length,
                  itemBuilder: (context, index) => FadeTransition(
                    opacity: _fadeAnimations[index],
                    child: _buildPanelText(context, _panels[index]),
                  ),
                ),
              ),
              _buildDots(palette),
              const SizedBox(height: 12),
              _buildPrimaryButton(),
              SizedBox(
                height: 52,
                child: _onLastPage
                    ? _QuietTextButton(
                        label: 'Not now',
                        color: palette.textSecondary,
                        onPressed: () =>
                            _completeOnboarding(openCapture: false),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelText(BuildContext context, _OnboardingPanel panel) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              panel.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: SeedlingTypography.serifFamily,
                fontSize: 28,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.25,
                height: 1.25,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            panel.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.15,
              height: 1.55,
              color: palette.textSecondary,
            ),
          ),
          if (panel.asksForIntention) ...[
            const SizedBox(height: 22),
            _buildIntentionField(),
            const SizedBox(height: 10),
            Text(
              'Optional. You can change it in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDots(SeedlingPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_panels.length, (index) {
        final isActive = index == _currentPage;
        return Semantics(
          button: true,
          selected: isActive,
          label: 'Page ${index + 1} of ${_panels.length}',
          onTap: () => _goToPage(index),
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey('onboarding-dot-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _goToPage(index),
            child: SizedBox(
              height: 44,
              width: isActive ? 44 : 28,
              child: Center(
                child: AnimatedContainer(
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? palette.primary
                        : palette.textMuted.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildIntentionField() {
    final palette = context.palette;
    final textStyle = TextStyle(fontSize: 17, color: palette.textPrimary);
    final hintStyle = TextStyle(fontSize: 17, color: palette.textMuted);
    final fill = palette.isDark ? palette.card : palette.surface;
    void submit(String _) => _goToPage(_currentPage + 1);

    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        key: const ValueKey('onboarding-intention'),
        controller: _intentionController,
        focusNode: _intentionFocus,
        placeholder: onboardingIntentionHint,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        maxLength: 80,
        minLines: 1,
        maxLines: 2,
        style: textStyle,
        placeholderStyle: hintStyle,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: SeedlingRadius.card,
          border: Border.all(color: palette.border),
        ),
        onSubmitted: submit,
      );
    }
    return TextField(
      key: const ValueKey('onboarding-intention'),
      controller: _intentionController,
      focusNode: _intentionFocus,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      maxLength: 80,
      minLines: 1,
      maxLines: 2,
      style: textStyle,
      decoration: InputDecoration(
        hintText: onboardingIntentionHint,
        hintStyle: hintStyle,
        hintMaxLines: 2,
        counterText: '',
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SeedlingRadius.card,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SeedlingRadius.card,
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      onSubmitted: submit,
    );
  }

  /// "Next" on every page, "Add your first memory" on the last.
  Widget _buildPrimaryButton() {
    final palette = context.palette;
    final label = _onLastPage ? 'Add your first memory' : 'Next';
    void onPressed() {
      if (_onLastPage) {
        _completeOnboarding(openCapture: true);
      } else {
        _goToPage(_currentPage + 1);
      }
    }

    final child = Text(
      label,
      key: const ValueKey('onboarding-primary'),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, minHeight: 52),
        child: SizedBox(
          width: double.infinity,
          child: PlatformUtils.isIOS
              ? CupertinoButton(
                  color: palette.primaryFill,
                  borderRadius: SeedlingRadius.button,
                  onPressed: onPressed,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: palette.onPrimaryFill),
                    child: child,
                  ),
                )
              : FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primaryFill,
                    foregroundColor: palette.onPrimaryFill,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: SeedlingRadius.button,
                    ),
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// A plain text button that looks at home on both platforms.
class _QuietTextButton extends StatelessWidget {
  const _QuietTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
    );
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onPressed: onPressed,
        child: text,
      );
    }
    return TextButton(onPressed: onPressed, child: text);
  }
}

/// Seedling's own tree, drawn by the same illustration the home screen uses,
/// at a given growth (0 seed .. 4 young tree). It follows the page swipe, so
/// the seed sprouts and grows as you move through onboarding.
class _OnboardingTree extends StatelessWidget {
  const _OnboardingTree({required this.growth});

  final double growth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide.clamp(0.0, 280.0);
        if (side < 96) return const SizedBox.shrink();
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: DecoratedBox(
              // One soft halo behind the tree, nothing else.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, 0.25),
                  radius: 0.55,
                  colors: [
                    palette.primaryContainer.withValues(alpha: 0.7),
                    palette.primaryContainer.withValues(alpha: 0),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _TreePagePainter(
                  TreeScene(
                    growth: growth,
                    season: Season.spring,
                    // Daylight greens, in both themes: on the dark ground
                    // they read rich and alive where the moonlit palette
                    // would sink into the background at this size.
                    night: false,
                    seed: _onboardingTreeSeed,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TreePagePainter extends CustomPainter {
  _TreePagePainter(this.scene);

  final TreeScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    // The illustration draws a seed tiny and a young tree large in the same
    // canvas. Here the young tree fills the frame and earlier stages are
    // enlarged about the ground line, so each stage reads clearly.
    final enlarge = 1 + (3.55 - scene.growth).clamp(0.0, 3.0) * 0.32;
    final groundY = size.height * treeGroundFraction(scene.growth);
    canvas.save();
    canvas.translate(size.width / 2, groundY);
    canvas.scale(enlarge);
    canvas.translate(-size.width / 2, -groundY);
    TreeIllustration(scene).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TreePagePainter oldDelegate) =>
      oldDelegate.scene != scene;
}
