import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/features/capture/presentation/quick_capture_sheet.dart';
import 'package:seedling/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stand-in for the tree screen: opens capture when onboarding asked for it.
class _Home extends ConsumerStatefulWidget {
  const _Home();

  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openPendingFirstCapture(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home')));
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget app() {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _Home()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('Skip finishes onboarding without opening capture', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(QuickCaptureSheet), findsNothing);
    expect(prefs.getBool(PrefsKeys.onboardingCompleted), isTrue);
  });

  testWidgets('page dots are tappable', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Seedling'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-dot-3')));
    await tester.pumpAndSettle();

    expect(find.text('Start with one memory'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('the intention is optional and becomes the capture hint', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-dot-2')));
    await tester.pumpAndSettle();
    expect(find.text('When do small moments find you?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-intention')),
      'When I make my morning coffee',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      prefs.getString(PrefsKeys.captureIntention),
      'When I make my '
      'morning coffee',
    );

    // "Add your first memory" keeps its promise: home, then capture.
    await tester.ensureVisible(find.text('Add your first memory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first memory'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(QuickCaptureSheet), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('capture-text')),
    );
    expect(
      field.decoration?.hintText,
      'When I make my morning coffee… what stayed with you?',
    );
  });

  testWidgets('skipping the intention leaves the default hint', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-dot-3')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add your first memory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first memory'));
    await tester.pumpAndSettle();

    expect(prefs.getString(PrefsKeys.captureIntention), isNull);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('capture-text')),
    );
    expect(field.decoration?.hintText, 'What stayed with you?');
  });

  testWidgets('every page has a visible primary button', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    const titles = [
      'Welcome to Seedling',
      'Every memory is a seed',
      'When do small moments find you?',
      'Start with one memory',
    ];
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      final primary = find.byKey(const ValueKey('onboarding-primary'));
      expect(primary, findsOneWidget);
      expect(tester.getRect(primary).bottom, lessThan(600));
      if (i < titles.length - 1) {
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Add your first memory'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
      }
    }
  });

  testWidgets('with Reduce Motion the pages switch without animating', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Next'));
    // One frame is enough: the page jumps instead of sliding.
    await tester.pump();
    final title = find.text('Every memory is a seed');
    expect(title, findsOneWidget);
    final afterOneFrame = tester.getCenter(title);
    await tester.pumpAndSettle();
    expect(tester.getCenter(title), afterOneFrame);
  });

  testWidgets('the intention example never truncates', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-dot-2')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('onboarding-intention')),
    );
    expect(field.decoration?.hintText, onboardingIntentionHint);
    expect(field.decoration?.hintMaxLines, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  test('captureHintFor trims trailing punctuation', () {
    expect(captureHintFor(null), 'What stayed with you?');
    expect(captureHintFor('   '), 'What stayed with you?');
    expect(
      captureHintFor('On my walk home. '),
      'On my walk home… what stayed with you?',
    );
  });
}
