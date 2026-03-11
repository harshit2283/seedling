import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/colors.dart';
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

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _tap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: _buildCard(context),
        ),
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
    final cardColor = Colors.white.withValues(alpha: 0.9);
    final borderColor = SeedlingColors.paleGreen.withValues(alpha: 0.35);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SeedlingColors.paleGreen.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final labelColor = SeedlingColors.textSecondary;
    final bodyColor = SeedlingColors.textPrimary;
    final iconBgColor = SeedlingColors.leafGreen.withValues(alpha: 0.15);
    final iconColor = SeedlingColors.forestGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _tap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Prompt icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PlatformUtils.isIOS
                      ? CupertinoIcons.sparkles
                      : Icons.auto_awesome,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Prompt text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gentle prompt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.prompt.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: bodyColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Dismiss button
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                    color: labelColor,
                    size: 18,
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
