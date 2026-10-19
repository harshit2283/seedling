import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/providers.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/typography.dart';

/// Data model for a single onboarding panel.
class _OnboardingPanel {
  final IconData symbol;
  final String title;
  final String subtitle;
  final List<Color> glowColors;

  /// The panel that asks for the person's own capture cue.
  final bool asksForIntention;

  const _OnboardingPanel({
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.glowColors,
    this.asksForIntention = false,
  });
}

const _panels = [
  _OnboardingPanel(
    symbol: CupertinoIcons.sparkles,
    title: 'Welcome to Seedling',
    subtitle: 'A calm place to keep what mattered.',
    glowColors: [Color(0xFFE7F2DB), Color(0xFFF6EED9)],
  ),
  _OnboardingPanel(
    symbol: CupertinoIcons.tree,
    title: 'Every memory is a seed',
    subtitle:
        'Save thoughts, moments, and feelings.\nWatch them shape your tree over time.',
    glowColors: [Color(0xFFD8E8D0), Color(0xFFF2E8D7)],
  ),
  _OnboardingPanel(
    symbol: CupertinoIcons.time,
    title: 'When do small moments find you?',
    subtitle:
        'Tie Seedling to something you already do. We\'ll keep it as a '
        'quiet hint, nothing more.',
    glowColors: [Color(0xFFE9EEDC), Color(0xFFF4E9D6)],
    asksForIntention: true,
  ),
  _OnboardingPanel(
    symbol: CupertinoIcons.leaf_arrow_circlepath,
    title: 'Start with one memory',
    subtitle: 'Your tree is ready to begin.',
    glowColors: [Color(0xFFE3F1D8), Color(0xFFEFE6D1)],
  ),
];

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
        duration: const Duration(milliseconds: 450),
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

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final backgroundColor = context.palette.background;
    final textColor = context.palette.textPrimary;
    final subtitleColor = context.palette.textSecondary;
    final mutedColor = context.palette.textMuted;
    final accentColor = context.palette.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
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
                        color: subtitleColor,
                        onPressed: () =>
                            _completeOnboarding(openCapture: false),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _panels.length,
                itemBuilder: (context, index) {
                  final panel = _panels[index];
                  final isLastPanel = index == _panels.length - 1;

                  return FadeTransition(
                    opacity: _fadeAnimations[index],
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _OnboardingHero(
                                panel: panel,
                                accentColor: accentColor,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 40),
                              Text(
                                panel.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: SeedlingTypography.serifFamily,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.25,
                                  height: 1.3,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                panel.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.15,
                                  height: 1.6,
                                  color: subtitleColor,
                                ),
                              ),
                              if (panel.asksForIntention) ...[
                                const SizedBox(height: 28),
                                _buildIntentionField(
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                  accentColor: accentColor,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Optional. You can change it in Settings.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _QuietTextButton(
                                  label: 'Continue',
                                  color: accentColor,
                                  onPressed: () => _goToPage(index + 1),
                                ),
                              ],
                              if (isLastPanel) ...[
                                const SizedBox(height: 48),
                                _buildActionButton(context.palette.primaryFill),
                                const SizedBox(height: 8),
                                _QuietTextButton(
                                  label: 'Not now',
                                  color: subtitleColor,
                                  onPressed: () =>
                                      _completeOnboarding(openCapture: false),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dot indicators (tappable)
            Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Row(
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
                        width: isActive ? 40 : 24,
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
                                  ? accentColor
                                  : mutedColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentionField({
    required Color textColor,
    required Color mutedColor,
    required Color accentColor,
    required bool isDark,
  }) {
    const hint = 'e.g. When I make my morning coffee';
    final fill = context.palette.surfaceMuted;
    if (Platform.isIOS) {
      return CupertinoTextField(
        key: const ValueKey('onboarding-intention'),
        controller: _intentionController,
        focusNode: _intentionFocus,
        placeholder: hint,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 80,
        style: TextStyle(fontSize: 17, color: textColor),
        placeholderStyle: TextStyle(fontSize: 17, color: mutedColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
        ),
        onSubmitted: (_) => _goToPage(_currentPage + 1),
      );
    }
    return TextField(
      key: const ValueKey('onboarding-intention'),
      controller: _intentionController,
      focusNode: _intentionFocus,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 80,
      style: TextStyle(fontSize: 17, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 17, color: mutedColor),
        counterText: '',
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.6)),
        ),
      ),
      onSubmitted: (_) => _goToPage(_currentPage + 1),
    );
  }

  Widget _buildActionButton(Color accentColor) {
    void onPressed() => _completeOnboarding(openCapture: true);
    if (Platform.isIOS) {
      return CupertinoButton.filled(
        borderRadius: BorderRadius.circular(20),
        onPressed: onPressed,
        child: const Text(
          'Add your first memory',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: context.palette.onPrimaryFill,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text(
        'Add your first memory',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    if (Platform.isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onPressed: onPressed,
        child: text,
      );
    }
    return TextButton(onPressed: onPressed, child: text);
  }
}

class _OnboardingHero extends StatelessWidget {
  final _OnboardingPanel panel;
  final Color accentColor;
  final bool isDark;

  const _OnboardingHero({
    required this.panel,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseBorder = context.palette.divider;

    return SizedBox(
      width: 196,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 188,
            height: 188,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: panel.glowColors
                    .map(
                      (color) => isDark
                          ? Color.lerp(color, context.palette.background, 0.7)!
                          : color,
                    )
                    .toList(),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 8),
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: isDark
                    ? SeedlingColors.cardDark.withValues(alpha: 0.92)
                    : SeedlingColors.warmWhite.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: baseBorder),
                boxShadow: [
                  BoxShadow(
                    color: context.palette.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 28,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 34,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Icon(panel.symbol, size: 62, color: accentColor),
        ],
      ),
    );
  }
}
