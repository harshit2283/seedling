import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/prefs_keys.dart';
import '../core/platform/platform_utils.dart';
import '../features/tree/presentation/tree_screen.dart';
import '../features/tree/presentation/forest_screen.dart';
import '../features/memories/presentation/memories_screen.dart';
import '../features/memories/presentation/entry_detail_screen.dart';
import '../features/memories/presentation/memory_reader_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/deleted_entries_screen.dart';
import '../features/settings/presentation/theme_insights_screen.dart';
import '../features/capsules/presentation/capsules_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/memories/presentation/object_gallery_screen.dart';
import '../features/review/presentation/year_in_review_screen.dart';
import '../features/settings/presentation/rituals_screen.dart';

/// App routes
class AppRoutes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String memories = '/memories';
  static const String memoryReader = '/memories/reader';
  static const String forest = '/forest';
  static const String entryDetail = '/entry/:id';
  static const String settings = '/settings';
  static const String deletedEntries = '/settings/deleted';
  static const String themeInsights = '/settings/themes';
  static const String rituals = '/settings/rituals';
  static const String capsules = '/capsules';
  static const String collection = '/collection';
  static const String yearReview = '/review/:year';

  static String entryRoute(int id) => '/entry/$id';
  static String yearReviewRoute(int year) => '/review/$year';
}

/// Creates the GoRouter with onboarding redirect support
GoRouter createAppRouter(SharedPreferences prefs) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final onboardingDone =
          prefs.getBool(PrefsKeys.onboardingCompleted) ?? false;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!onboardingDone && !isOnboarding) {
        return AppRoutes.onboarding;
      }
      if (onboardingDone && isOnboarding) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => _buildPage(
          key: state.pageKey,
          child: const TreeScreen(),
          isRoot: true,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => _buildPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          isRoot: true,
        ),
      ),
      GoRoute(
        path: AppRoutes.memories,
        name: 'memories',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const MemoriesScreen()),
      ),
      GoRoute(
        path: AppRoutes.memoryReader,
        name: 'memoryReader',
        pageBuilder: (context, state) {
          final args = state.extra;
          if (args is! MemoryReaderArgs) {
            return _buildPage(
              key: state.pageKey,
              child: const MemoriesScreen(),
            );
          }
          return _buildPage(
            key: state.pageKey,
            child: MemoryReaderScreen(args: args),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forest,
        name: 'forest',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const ForestScreen()),
      ),
      GoRoute(
        path: AppRoutes.entryDetail,
        name: 'entry',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _buildPage(
            key: state.pageKey,
            child: EntryDetailScreen(entryId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.deletedEntries,
        name: 'deletedEntries',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const DeletedEntriesScreen()),
      ),
      GoRoute(
        path: AppRoutes.themeInsights,
        name: 'themeInsights',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const ThemeInsightsScreen()),
      ),
      GoRoute(
        path: AppRoutes.rituals,
        name: 'rituals',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const RitualsScreen()),
      ),
      GoRoute(
        path: AppRoutes.collection,
        name: 'collection',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const ObjectGalleryScreen()),
      ),
      GoRoute(
        path: AppRoutes.capsules,
        name: 'capsules',
        pageBuilder: (context, state) =>
            _buildPage(key: state.pageKey, child: const CapsulesScreen()),
      ),
      GoRoute(
        path: AppRoutes.yearReview,
        name: 'yearReview',
        pageBuilder: (context, state) {
          final year =
              int.tryParse(state.pathParameters['year'] ?? '') ??
              DateTime.now().year;
          return _buildPage(
            key: state.pageKey,
            child: YearInReviewScreen(year: year),
          );
        },
      ),
    ],
  );
}

/// Legacy global router for backward compatibility during migration.
/// New code should use createAppRouter() instead.
late final GoRouter appRouter;

/// Builds a page with platform-appropriate transitions
Page<dynamic> _buildPage({
  required LocalKey key,
  required Widget child,
  bool isRoot = false,
}) {
  if (PlatformUtils.isIOS) {
    // iOS: Cupertino slide from right transition
    return CupertinoPage(key: key, child: child);
  }

  // Android: Custom Material transitions
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (isRoot) {
        // Root page: simple fade
        return FadeTransition(opacity: animation, child: child);
      }

      // Other pages: slide up with fade
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
