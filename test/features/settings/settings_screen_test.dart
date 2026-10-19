import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/router.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/notifications/gentle_reminder_service.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/storage/storage_usage_service.dart';
import 'package:seedling/data/datasources/local/objectbox_database.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/settings/presentation/settings_screen.dart';
import 'package:seedling/features/settings/presentation/sync_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDb extends Mock implements ObjectBoxDatabase {}

void main() {
  late _MockDb db;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(Entry.line(text: ''));
  });

  setUp(() async {
    db = _MockDb();
    when(() => db.watchEntries()).thenAnswer((_) => Stream.value(const []));
    when(() => db.watchAllEntries()).thenAnswer((_) => Stream.value(const []));
    when(() => db.watchCurrentTree()).thenAnswer((_) => Stream.value(null));
    when(() => db.watchRituals()).thenAnswer((_) => Stream.value(const []));
    when(() => db.getAllEntries()).thenReturn(const []);
    when(() => db.getAllCapsules()).thenReturn(const []);
    when(() => db.getDeletedEntries()).thenReturn(const []);
    when(() => db.getCapsulesToUnlockToday()).thenReturn(const []);
    when(() => db.getAllTrees()).thenReturn(const []);
    when(
      () => db.getEntriesCount(
        year: any(named: 'year'),
        includeDeleted: any(named: 'includeDeleted'),
        includeLockedCapsules: any(named: 'includeLockedCapsules'),
      ),
    ).thenReturn(0);
  });

  Future<void> pump(
    WidgetTester tester, {
    String initial = AppRoutes.settings,
    Map<String, Object> prefsInit = const {},
  }) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefsInit);
    prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSync,
          builder: (_, _) => const SyncSettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsData,
          builder: (_, _) => const Scaffold(body: Text('export screen')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          gentleReminderServiceProvider.overrideWithValue(
            GentleReminderService(prefs: prefs),
          ),
          storageUsageProvider.overrideWith(
            (ref) async => const StorageUsage(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings is five short groups in sentence case', (tester) async {
    await pump(tester);
    for (final header in [
      'Your tree',
      'Gentle nudges',
      'Privacy & sync',
      'Your memories',
      'About',
    ]) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    // Old plumbing and title-case labels are gone.
    for (final gone in [
      'Your Tree',
      'Storage Used',
      'Danger Zone',
      'Sync (optional)',
      'Enable App Lock',
      'Set Sync Passphrase',
      'Theme Insights',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('cloud sync and app lock each appear exactly once', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.textContaining(RegExp('sync', caseSensitive: false)),
      findsNWidgets(2),
    ); // the "Privacy & sync" header and the one row
    expect(find.byKey(const ValueKey('settings-cloud-sync')), findsOneWidget);
    expect(find.text('Cloud sync'), findsOneWidget);
    expect(find.text('App lock'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-app-lock')), findsOneWidget);
    expect(find.textContaining('passphrase'), findsNothing);
  });

  testWidgets('cloud sync opens one screen with the opt-in, off by default', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('settings-cloud-sync')));
    await tester.pumpAndSettle();

    expect(find.text(syncIntro), findsOneWidget);
    final allow = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const ValueKey('sync-allow-switch')),
        matching: find.byType(Switch),
      ),
    );
    expect(allow.value, isFalse);
    // Nothing else about sync is offered until the person allows it.
    expect(find.text('Sync passphrase'), findsNothing);
    expect(find.text('Sync this device'), findsNothing);
  });

  testWidgets('allowing sync reveals passphrase and status on that screen', (
    tester,
  ) async {
    await pump(
      tester,
      initial: AppRoutes.settingsSync,
      prefsInit: {PrefsKeys.cloudSyncEnabled: true},
    );
    expect(find.text('Sync passphrase'), findsOneWidget);
    expect(find.text('Sync this device'), findsOneWidget);
  });

  testWidgets('rebuild tree counts stays reachable under Advanced', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Rebuild tree counts'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-advanced')));
    await tester.pumpAndSettle();
    expect(find.text('Rebuild tree counts'), findsOneWidget);
    expect(find.text('Clear all data'), findsOneWidget);
  });

  testWidgets('export and import live on one sub-screen', (tester) async {
    await pump(tester);
    expect(find.text('Export as ZIP'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-export-import')));
    await tester.pumpAndSettle();
    expect(find.text('export screen'), findsOneWidget);
  });

  testWidgets('support is visible in About, warm and without pressure', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('settings-support')), findsOneWidget);
    expect(
      find.text('Free and open source. Nothing is locked.'),
      findsOneWidget,
    );
  });

  testWidgets('list rows paint ripples on the card, not behind it', (
    tester,
  ) async {
    await pump(tester);
    // Walking up from each ripple, a Material must come before any
    // coloured box; otherwise the box hides the ink.
    final inks = find.byType(InkWell).evaluate().toList();
    expect(inks, isNotEmpty);
    for (final ink in inks) {
      String? hiddenBy;
      ink.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is Material) return false;
        if (widget is DecoratedBox) {
          final d = widget.decoration;
          if (d is BoxDecoration && (d.color?.a ?? 0) > 0) {
            hiddenBy = '$widget';
            return false;
          }
        }
        return true;
      });
      expect(hiddenBy, isNull, reason: 'ripple hidden by $hiddenBy');
    }
    expect(tester.takeException(), isNull);
  });
}
