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

  /// Gap between the button and the bottom safe area on iOS.
  static double iosBottomOffset(BuildContext context) =>
      math.max(MediaQuery.viewPaddingOf(context).bottom, 16) + 8;

  /// Scroll padding the page keeps clear under its content: the button,
  /// its margin to the screen edge and a little breathing room above it.
  static double reservedHeight(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _pillHeight + iosBottomOffset(context) + 24;
    }
    // FloatingActionButtonLocation.centerFloat sits 16dp above the safe
    // area.
    return _fabHeight + 16 + MediaQuery.viewPaddingOf(context).bottom + 24;
  }

  void _tap() {
    HapticFeedback.selectionClick();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (!PlatformUtils.isIOS) {
      return FloatingActionButton.extended(
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
            borderRadius: BorderRadius.circular(_pillHeight / 2),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_pillHeight / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: _pillHeight,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  color: palette.primaryFill.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(_pillHeight / 2),
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
                    Text(
                      'Add memory',
                      style: TextStyle(
                        color: palette.onPrimaryFill,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
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
