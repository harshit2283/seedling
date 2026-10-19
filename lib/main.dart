import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/services/export/export_cleanup.dart';
import 'core/services/media/file_storage_service.dart';
import 'core/services/notifications/gentle_reminder_service.dart';
import 'core/services/providers.dart';
import 'core/services/security/clock_guard_service.dart';
import 'core/services/storage/media_orphan_sweeper.dart';
import 'core/services/share/share_receiver_service.dart';
import 'core/services/widget/widget_data_service.dart';
import 'data/datasources/local/objectbox_database.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcherError: $error');
    return true;
  };

  await runZonedGuarded(
    () async {
      await _runApp();
    },
    (error, stackTrace) {
      debugPrint('UncaughtZoneError: $error');
    },
  );
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay style is now handled dynamically by the theme
  // The AppBarTheme.systemOverlayStyle adapts to light/dark mode
  // Setting edgeToEdge mode allows the app to draw behind system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize database
  final database = await ObjectBoxDatabase.create();
  database.attachErrorReporter(const ErrorReporter());

  // Initialize file storage service for media
  final fileStorageService = FileStorageService();
  await fileStorageService.init();
  database.attachFileStorage(fileStorageService);

  // Initialize clock guard for capsule lock integrity
  final clockGuardService = ClockGuardService();
  await clockGuardService.init();
  database.attachClockGuard(clockGuardService);

  // Purge expired soft-deleted entries (also cleans their media files now
  // that file storage is attached).
  await database.purgeExpiredEntries();

  // Initialize SharedPreferences for prompts and settings
  final sharedPreferences = await SharedPreferences.getInstance();
  // Reminders are opt-in and off by default: the plugin initializes lazily on
  // first reschedule, so startup never waits on a permission prompt.
  final gentleReminderService = GentleReminderService(prefs: sharedPreferences);

  // Initialize share receiver service (Phase 4.5)
  final shareReceiverService = ShareReceiverService();
  shareReceiverService.init();

  // Initialize widget data service (Phase 4.5)
  final widgetDataService = WidgetDataService();
  await widgetDataService.init();

  // Initialize router with onboarding redirect support
  appRouter = createAppRouter(sharedPreferences);

  runApp(
    ProviderScope(
      overrides: [
        // Provide the initialized database
        databaseProvider.overrideWithValue(database),
        // Provide the initialized file storage service
        fileStorageServiceProvider.overrideWithValue(fileStorageService),
        // Provide the initialized SharedPreferences
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Provide the initialized share receiver service
        shareReceiverServiceProvider.overrideWithValue(shareReceiverService),
        // Provide the initialized widget data service
        widgetDataServiceProvider.overrideWithValue(widgetDataService),
        // Provide initialized reminder service
        gentleReminderServiceProvider.overrideWithValue(gentleReminderService),
      ],
      child: const SeedlingApp(),
    ),
  );

  // Housekeeping that must never delay the first frame.
  unawaited(_sweepTransientFiles());
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 20),
      () => _sweepOrphanMedia(database, fileStorageService),
    ),
  );
}

/// Deletes media files no entry (live or in the 30-day trash) references,
/// e.g. photos from drafts discarded by older builds. Delayed so it never
/// competes with first-frame work.
Future<void> _sweepOrphanMedia(
  ObjectBoxDatabase database,
  FileStorageService fileStorage,
) async {
  try {
    final entries = [
      ...database.getAllEntries(),
      ...database.getDeletedEntries(),
    ];
    final deleted = await const MediaOrphanSweeper().sweep(
      mediaDirectory: Directory(fileStorage.basePath),
      referencedPaths: entries.map((e) => e.mediaPath),
    );
    if (deleted > 0) debugPrint('Removed $deleted orphaned media files');
  } catch (e) {
    debugPrint('Orphan media sweep failed: $e');
  }
}

/// Deletes plaintext export/share leftovers (e.g. from a share sheet that was
/// open when the app was killed).
Future<void> _sweepTransientFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    await sweepStaleExportArtifacts(tempDir);
  } catch (e) {
    debugPrint('Startup export sweep failed: $e');
  }
}
