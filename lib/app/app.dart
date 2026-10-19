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
import 'app_lock_gate.dart';
import 'router.dart';
import 'theme/cupertino_theme.dart';
import 'theme/seedling_theme.dart';
import '../core/widgets/feedback/seedling_toast.dart';

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

    // Decide the lock state before the first frame so a cold start never
    // renders memories unlocked, even for one frame.
    final initialLockEnabled = ref.read(appLockEnabledProvider);
    _lastKnownLockEnabled = initialLockEnabled;
    _isLocked = initialLockEnabled;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lockEnabled = ref.read(appLockEnabledProvider);
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));

      // Initialize cloud sync engine only if the master opt-in is on.
      if (ref.read(cloudSyncEnabledProvider)) {
        ref.read(syncEngineProvider).init();
      }
      // Mount the master cloud-sync listener so flipping the master toggle
      // off cleanly tears down any active sync session.
      ref.read(cloudSyncMasterGateProvider);
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
        showSeedlingMessage(navContext, message);
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
    final lockEnabled = ref.read(appLockEnabledProvider);

    // `inactive` alone is not backgrounding: the Face ID sheet, permission
    // dialogs and the camera picker all pass through inactive -> resumed.
    // Treating it as backgrounding re-locked the app right after unlocking.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      // Write any debounced widget update before the OS suspends us.
      ref.read(widgetDataServiceProvider).flush();
      // Lock on the way out (not on return) so the app-switcher snapshot
      // already shows the lock screen.
      if (lockEnabled && mounted && !_isLocked) {
        setState(() => _isLocked = true);
      }
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));
    }

    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      unawaited(_applyScreenProtection(lockEnabled: lockEnabled));

      // Pull only when the user opted in to cloud sync.
      if (ref.read(cloudSyncEnabledProvider)) {
        ref.read(syncEngineProvider).pull();
      }
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
    return AppLockGate(
      locked: lockEnabled && _isLocked,
      isUnlocking: _isUnlocking,
      onUnlock: _unlockApp,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep home widgets in sync with latest tree/entry data.
    ref.watch(widgetAutoUpdateProvider);
    ref.watch(reminderAutoRescheduleProvider);
    ref.watch(resurfaceNotificationAutoScheduleProvider);

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
                return wrapCupertinoAppContent(
                  materialTheme: isDark
                      ? SeedlingTheme.dark
                      : SeedlingTheme.light,
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
