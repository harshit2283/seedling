import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/providers.dart';
import '../../../app/theme/colors.dart';

/// Data model for a single onboarding panel.
class _OnboardingPanel {
  final IconData symbol;
  final String title;
  final String subtitle;
  final List<Color> glowColors;

  const _OnboardingPanel({
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.glowColors,
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
  int _currentPage = 0;

  /// Animation controllers for each panel's fade-in.
  late final List<AnimationController> _fadeControllers;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();

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

    // Start the first panel's animation immediately.
    _fadeControllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _fadeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    // Trigger fade-in for the new panel.
    _fadeControllers[page].forward(from: 0.0);
  }

  Future<void> _completeOnboarding() async {
    final onboarding = ref.read(onboardingPreferencesProvider);
    await onboarding.setCompleted();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final backgroundColor = isDark
        ? SeedlingColors.backgroundDark
        : SeedlingColors.creamPaper;
    final textColor = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final subtitleColor = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final mutedColor = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    final accentColor = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
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
                                  fontFamily: Platform.isIOS
                                      ? '.AppleSystemUIFont'
                                      : 'Georgia',
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
                              if (isLastPanel) ...[
                                const SizedBox(height: 48),
                                _buildActionButton(accentColor),
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

            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_panels.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? accentColor
                          : mutedColor.withValues(alpha: 0.3),
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

  Widget _buildActionButton(Color accentColor) {
    if (Platform.isIOS) {
      return CupertinoButton.filled(
        borderRadius: BorderRadius.circular(20),
        onPressed: _completeOnboarding,
        child: const Text(
          'Add your first memory',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _completeOnboarding,
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
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
    final baseBorder = isDark
        ? SeedlingColors.dividerDark
        : SeedlingColors.softCream;

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
                          ? Color.lerp(color, Colors.black, 0.55)!
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
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
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
