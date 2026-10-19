import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/palette.dart';

/// Button for selecting entry type in the capture sheet.
///
/// Unselected buttons stay quiet (secondary text, hairline border) but keep
/// AA contrast; the selected one gains a tinted fill and accent border.
/// Exposed to assistive tech as a selectable button.
class EntryTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  /// Overrides the spoken label (defaults to [label]).
  final String? semanticLabel;

  /// Extra spoken hint describing what the mode does.
  final String? semanticHint;

  const EntryTypeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.semanticLabel,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final foreground = isSelected
        ? palette.inkFor(color)
        : palette.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel ?? label,
      hint: semanticHint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : palette.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : foreground, size: 22),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
