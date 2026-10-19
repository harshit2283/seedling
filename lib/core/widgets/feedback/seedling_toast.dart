import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';
import '../../platform/platform_utils.dart';

OverlayEntry? _activeToast;
Timer? _activeToastTimer;

/// Shows a short, non-blocking message.
///
/// Use this instead of calling `ScaffoldMessenger.of(context)` directly: the
/// iOS shell is a [CupertinoApp] whose pages are [CupertinoPageScaffold]s, so
/// there is no [Scaffold] to present a [SnackBar] in and the call fails. On
/// iOS (and anywhere no [ScaffoldMessenger] is available) this renders a soft
/// pill in the root overlay; on Android it uses the regular snackbar.
void showSeedlingMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  if (!PlatformUtils.isIOS) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _errorFill(context.palette) : null,
          duration: duration,
        ),
      );
      return;
    }
  }

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  dismissSeedlingMessage();
  final entry = OverlayEntry(
    builder: (context) => _SeedlingToast(message: message, isError: isError),
  );
  _activeToast = entry;
  overlay.insert(entry);
  _activeToastTimer = Timer(duration, dismissSeedlingMessage);
}

/// Removes the currently visible toast, if any.
void dismissSeedlingMessage() {
  _activeToastTimer?.cancel();
  _activeToastTimer = null;
  final entry = _activeToast;
  _activeToast = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _SeedlingToast extends StatelessWidget {
  const _SeedlingToast({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = isError
        ? _errorFill(palette)
        : (palette.isDark ? palette.surfaceMuted : palette.primaryFill);
    final foreground = palette.isDark
        ? palette.textPrimary
        : palette.onPrimaryFill;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 24,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: GestureDetector(
          onTap: dismissSeedlingMessage,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 12),
                child: child,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A deeper error tone for filled backgrounds so light text stays AA.
Color _errorFill(SeedlingPalette palette) =>
    palette.isDark ? const Color(0xFF6B3434) : const Color(0xFFA94848);
