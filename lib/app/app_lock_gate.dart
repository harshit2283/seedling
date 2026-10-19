import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Covers the app while it is locked.
///
/// The app underneath stays mounted so navigation state survives a lock, but
/// it is kept [Offstage]: not painted, not hit-testable, and — importantly —
/// absent from the semantics tree, so a screen reader cannot read or activate
/// memories behind the lock screen.
class AppLockGate extends StatelessWidget {
  const AppLockGate({
    super.key,
    required this.locked,
    required this.isUnlocking,
    required this.onUnlock,
    required this.child,
  });

  final bool locked;
  final bool isUnlocking;
  final VoidCallback onUnlock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Offstage(
          offstage: locked,
          child: TickerMode(enabled: !locked, child: child),
        ),
        if (locked)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: Colors.white,
                      size: 50,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Seedling is locked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoButton.filled(
                      onPressed: isUnlocking ? null : onUnlock,
                      child: isUnlocking
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Wraps the routed app content for the iOS [CupertinoApp] shell.
///
/// [CupertinoApp] does not provide a [ScaffoldMessenger] the way
/// [MaterialApp] does, so a stray `ScaffoldMessenger.of(context)` would throw.
/// User-facing messages should go through `showSeedlingMessage`, which works
/// without a [Scaffold]; the messenger here is a safety net.
Widget wrapCupertinoAppContent({
  required ThemeData materialTheme,
  required Widget child,
}) {
  return Theme(
    data: materialTheme,
    child: ScaffoldMessenger(child: child),
  );
}
