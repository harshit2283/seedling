import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/platform/platform_utils.dart';
import '../core/services/providers.dart';
import '../core/services/share/share_receiver_service.dart';
import '../features/capture/presentation/quick_capture_sheet.dart';
import '../features/capture/presentation/shared_content_sheet.dart';
import 'router.dart';
import 'theme/cupertino_theme.dart';
import 'theme/seedling_theme.dart';

/// Root widget for the Seedling app
/// Uses CupertinoApp on iOS for native feel, MaterialApp on Android
/// Supports system dark/light mode detection on both platforms
class SeedlingApp extends ConsumerStatefulWidget {
  const SeedlingApp({super.key});

  @override
  ConsumerState<SeedlingApp> createState() => _SeedlingAppState();
}

class _SeedlingAppState extends ConsumerState<SeedlingApp>
    with WidgetsBindingObserver {
  static const MethodChannel _screenProtectionChannel = MethodChannel(
    'com.seedling.app/screen_protection',
  );
  StreamSubscription<SharedContent>? _shareSubscription;
  StreamSubscription<String>? _shareErrorSubscription;
  StreamSubscription<Uri?>? _widgetTapSubscription;
  bool _isLocked = false;
  bool _wasBackgrounded = false;
  bool _isUnlocking = false;
  bool? _lastKnownLockEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lockEnabled = ref.read(appLockEnabledProvider);
      _lastKnownLockEnabled = lockEnabled;
      if (lockEnabled) {
        setState(() => _isLocked = true);
      }
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));

      // Initialize cloud sync engine if enabled.
      ref.read(syncEngineProvider).init();
    });

    // Listen for shared content and widget taps after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupShareListener();
      _setupWidgetListener();
    });
  }

  void _setupShareListener() {
    final shareService = ref.read(shareReceiverServiceProvider);
    _shareSubscription = shareService.sharedContentStream.listen((content) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
        if (navContext == null) return;
        showSharedContentSheet(navContext, content);
      });
    });
    _shareErrorSubscription = shareService.sharedErrorStream.listen((message) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
        if (navContext == null) return;
        ScaffoldMessenger.of(
          navContext,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    });
  }

  void _setupWidgetListener() {
    final widgetService = ref.read(widgetDataServiceProvider);

    // Check if app was launched from widget
    widgetService.getInitialLaunchUri().then((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });

    // Listen for widget taps while app is running
    _widgetTapSubscription = widgetService.widgetTapStream.listen((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });
  }

  void _handleWidgetUri(Uri uri) {
    // Handle widget deep links
    if (uri.host == 'capture') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
        if (navContext == null) return;
        showQuickCaptureSheet(navContext);
      });
      return;
    }
    if (uri.host == 'today') {
      appRouter.go(AppRoutes.home);
      return;
    }
    // 'home' uri just opens the app, no special handling needed
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSubscription?.cancel();
    _shareErrorSubscription?.cancel();
    _widgetTapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      unawaited(
        _applyScreenProtection(lockEnabled: ref.read(appLockEnabledProvider)),
      );
    }

    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;

      // Lock screen if enabled
      final lockEnabled = ref.read(appLockEnabledProvider);
      if (lockEnabled && mounted) {
        setState(() => _isLocked = true);
      }
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));

      // Trigger cloud sync pull on resume
      final syncEngine = ref.read(syncEngineProvider);
      syncEngine.pull();
    }
  }

  Future<void> _applyScreenProtection({required bool lockEnabled}) async {
    try {
      await _screenProtectionChannel.invokeMethod<void>('setEnabled', {
        'enabled': lockEnabled || _isLocked,
      });
    } catch (_) {
      // No-op when platform channel is unavailable on this device.
    }
  }

  Future<void> _unlockApp() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    final lockService = ref.read(appLockServiceProvider);
    final canAuth = await lockService.canAuthenticate();
    if (!canAuth) {
      if (mounted) {
        setState(() => _isUnlocking = false);
      }
      return;
    }

    final didUnlock = await lockService.authenticate();
    if (!mounted) return;
    setState(() {
      _isUnlocking = false;
      if (didUnlock) {
        _isLocked = false;
      }
    });
    unawaited(
      _applyScreenProtection(lockEnabled: ref.read(appLockEnabledProvider)),
    );
  }

  Widget _wrapWithAppLock(Widget child) {
    final lockEnabled = ref.watch(appLockEnabledProvider);
    if (_lastKnownLockEnabled != lockEnabled) {
      _lastKnownLockEnabled = lockEnabled;
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));
    }
    if (!lockEnabled && _isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isLocked = false);
          unawaited(_applyScreenProtection(lockEnabled: lockEnabled));
        }
      });
    }
    if (!lockEnabled || !_isLocked) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.86),
            ),
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
                    onPressed: _isUnlocking ? null : _unlockApp,
                    child: _isUnlocking
                        ? const CupertinoActivityIndicator(color: Colors.white)
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

  @override
  Widget build(BuildContext context) {
    // Keep home widgets in sync with latest tree/entry data.
    ref.watch(widgetAutoUpdateProvider);
    ref.watch(reminderAutoRescheduleProvider);

    if (PlatformUtils.isIOS) {
      // Use MediaQuery to detect system brightness for Cupertino
      return MediaQuery.fromView(
        view: View.of(context),
        child: Builder(
          builder: (context) {
            final brightness = MediaQuery.platformBrightnessOf(context);
            final isDark = brightness == Brightness.dark;

            return CupertinoApp.router(
              title: 'Seedling',
              debugShowCheckedModeBanner: false,
              theme: isDark
                  ? SeedlingCupertinoTheme.dark
                  : SeedlingCupertinoTheme.light,
              routerConfig: appRouter,
              // Wrap with Material theme for widgets that need it
              builder: (context, child) {
                return Theme(
                  data: isDark ? SeedlingTheme.dark : SeedlingTheme.light,
                  child: _wrapWithAppLock(child ?? const SizedBox.shrink()),
                );
              },
            );
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'Seedling',
      debugShowCheckedModeBanner: false,
      theme: SeedlingTheme.light,
      darkTheme: SeedlingTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) =>
          _wrapWithAppLock(child ?? const SizedBox.shrink()),
    );
  }
}
