import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';

/// The home screen's one primary action.
///
/// iOS: a floating glass pill above the home indicator. Android: an
/// extended FAB (placed by the Scaffold). Either way the home content
/// reserves [reservedHeight] at its end so the button never sits on top of
/// the last thing on the page.
class AddMemoryButton extends StatelessWidget {
  const AddMemoryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _pillHeight = 52.0;
  static const _fabHeight = 56.0;
  static const _pillFontSize = 17.0;
  static const _fabFontSize = 16.0;

  /// The button's height with the current text size: its resting height,
  /// or taller when large text needs it (label line plus 14pt above and
  /// below).
  static double buttonHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final ios = PlatformUtils.isIOS;
    final base = ios ? _pillHeight : _fabHeight;
    final line = scaler.scale(ios ? _pillFontSize : _fabFontSize) * 1.25;
    return math.max(base, (line + 28).ceilToDouble());
  }

  /// Gap between the button and the bottom safe area on iOS.
  static double iosBottomOffset(BuildContext context) =>
      math.max(MediaQuery.viewPaddingOf(context).bottom, 16) + 8;

  /// Scroll padding the page keeps clear under its content: the button,
  /// its margin to the screen edge and a little breathing room above it.
  static double reservedHeight(BuildContext context) {
    final height = buttonHeight(context);
    if (PlatformUtils.isIOS) {
      return height + iosBottomOffset(context) + 24;
    }
    // FloatingActionButtonLocation.centerFloat sits 16dp above the safe
    // area.
    return height + 16 + MediaQuery.viewPaddingOf(context).bottom + 24;
  }

  void _tap() {
    HapticFeedback.selectionClick();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final height = buttonHeight(context);
    if (!PlatformUtils.isIOS) {
      // Held to [buttonHeight] so the page's reserved space is exact even
      // with large text.
      return SizedBox(
        height: height,
        child: FloatingActionButton.extended(
          key: const ValueKey('home-add-memory'),
          heroTag: 'home-add-memory',
          onPressed: _tap,
          backgroundColor: palette.primaryFill,
          foregroundColor: palette.onPrimaryFill,
          elevation: 2,
          highlightElevation: 4,
          shape: const StadiumBorder(),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
          icon: Icon(AdaptiveIcons.add),
          label: const Text(
            'Add memory',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _fabFontSize,
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Add memory',
      excludeSemantics: true,
      onTap: _tap,
      child: GestureDetector(
        key: const ValueKey('home-add-memory'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  color: palette.primaryFill.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(
                    color: palette.onPrimaryFill.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AdaptiveIcons.add,
                      color: palette.onPrimaryFill,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Add memory',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.onPrimaryFill,
                          fontSize: _pillFontSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
