import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/services/ai/theme_backfill_service.dart';
import 'core/services/diagnostics_log.dart';
import 'core/services/error_reporter.dart';
import 'core/services/export/export_cleanup.dart';
import 'core/services/media/draft_media_tracker.dart';
import 'core/services/media/file_storage_service.dart';
import 'core/services/notifications/gentle_reminder_service.dart';
import 'core/services/providers.dart';
import 'core/services/security/clock_guard_service.dart';
import 'core/services/security/ios_data_protection.dart';
import 'core/services/security/secure_storage.dart';
import 'core/services/sync/sync_backend.dart';
import 'core/services/sync/sync_metadata.dart';
import 'core/services/storage/media_orphan_sweeper.dart';
import 'core/services/share/share_receiver_service.dart';
import 'core/services/widget/widget_data_service.dart';
import 'data/datasources/local/objectbox_database.dart';

void main() async {
  // All uncaught errors go to the ErrorReporter: printed in debug, and kept
  // (redacted) in the local diagnostics log in every build. Nothing is sent
  // off the device.
  const reporter = ErrorReporter();
  installGlobalErrorHandlers(reporter);

  await runZonedGuarded(
    () async {
      await _runApp();
    },
    (error, stackTrace) {
      reporter.report(error, stack: stackTrace, context: 'Zone');
    },
  );
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local, rotating error log (Settings > About > Share diagnostics).
  try {
    DiagnosticsLog.instance = await DiagnosticsLog.open();
  } catch (_) {
    // Diagnostics are optional; the app runs without them.
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay style is now handled dynamically by the theme
  // The AppBarTheme.systemOverlayStyle adapts to light/dark mode
  // Setting edgeToEdge mode allows the app to draw behind system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Move pre-existing keychain secrets to device-only accessibility before
  // anything reads them.
  await SecureStorageAccessibilityMigration().run();

  // Initialize database
  final database = await ObjectBoxDatabase.create();
  database.attachErrorReporter(const ErrorReporter());

  // Initialize file storage service for media
  final fileStorageService = FileStorageService();
  await fileStorageService.init();
  database.attachFileStorage(fileStorageService);

  // Keep the database and media out of iCloud/iTunes backups (iOS).
  final dataProtection = IosDataProtection();
  await dataProtection.hardenDirectory(database.storeDirectory);
  await dataProtection.hardenDirectory(fileStorageService.basePath);

  // Initialize clock guard for capsule lock integrity
  final clockGuardService = ClockGuardService();
  await clockGuardService.init();
  database.attachClockGuard(clockGuardService);

  // Purge expired soft-deleted entries (also cleans their media files now
  // that file storage is attached).
  await database.purgeExpiredEntries();

  // Initialize SharedPreferences for prompts and settings
  final sharedPreferences = await SharedPreferences.getInstance();
  if (database.isFreshStore) {
    // Preferences survive a backup restore but the store does not, so drop
    // stale sync change tokens and let the next sync pull everything.
    for (final provider in SyncProviderType.values) {
      await SyncMetadata(
        sharedPreferences,
        namespace: provider.name,
      ).setChangeToken(null);
    }
  }
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
  // Persist themes on entries saved before themes were stored at capture.
  // Runs once, after startup settles, and classifies off the UI isolate.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 3),
      () => _backfillThemes(database, sharedPreferences),
    ),
  );
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 20),
      () => _sweepOrphanMedia(database, fileStorageService),
    ),
  );
}

Future<void> _backfillThemes(
  ObjectBoxDatabase database,
  SharedPreferences prefs,
) async {
  try {
    await ThemeBackfillService(database, prefs).run();
  } catch (e, stack) {
    const ErrorReporter().report(e, stack: stack, context: 'ThemeBackfill');
  }
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
      protectedPaths: DraftMediaTracker.liveDraftPaths,
    );
    if (deleted > 0) debugPrint('Removed $deleted orphaned media files');
  } catch (e, st) {
    const ErrorReporter().report(e, stack: st, context: 'Orphan media sweep');
  }
}

/// Deletes plaintext export/share leftovers (e.g. from a share sheet that was
/// open when the app was killed).
Future<void> _sweepTransientFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    await sweepStaleExportArtifacts(tempDir);
  } catch (e, st) {
    const ErrorReporter().report(e, stack: st, context: 'Export sweep');
  }
}
