import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../app/theme/typography.dart';
import '../../../core/platform/platform_utils.dart';
import '../data/prompt_repository.dart';

/// A subtle glass card displaying a gentle prompt
class PromptCard extends StatefulWidget {
  final GentlePrompt prompt;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const PromptCard({
    super.key,
    required this.prompt,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Start animation after a short delay (skipped under Reduce Motion,
    // see didChangeDependencies).
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_controller.isCompleted) {
        _controller.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce Motion: appear in place, no slide.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onDismiss();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  void _tap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SlideTransition(
      position: reduceMotion
          ? const AlwaysStoppedAnimation(Offset.zero)
          : _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(padding: EdgeInsets.zero, child: _buildCard(context)),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _buildIOSCard(context);
    }
    return _buildMaterialCard(context);
  }

  Widget _buildIOSCard(BuildContext context) {
    final palette = context.palette;
    final cardColor = palette.glassTint;
    final borderColor = palette.primaryContainer.withValues(alpha: 0.5);

    return ClipRRect(
      borderRadius: SeedlingRadius.card,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: SeedlingRadius.card,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: SeedlingRadius.card,
        border: Border.all(color: context.palette.border, width: 0.5),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _tap,
        borderRadius: SeedlingRadius.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.sparkles
                    : Icons.auto_awesome_outlined,
                color: palette.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  hint: 'Opens capture with this prompt',
                  child: Text(
                    widget.prompt.text,
                    style: TextStyle(
                      fontFamily: SeedlingTypography.serifFamily,
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      color: palette.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              // Dismiss button: 44x44 hit area, labelled for VoiceOver.
              Semantics(
                button: true,
                label: 'Dismiss prompt',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                      color: palette.textMuted,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
