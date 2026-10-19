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
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
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

  test('captureHintFor trims trailing punctuation', () {
    expect(captureHintFor(null), 'What stayed with you?');
    expect(captureHintFor('   '), 'What stayed with you?');
    expect(
      captureHintFor('On my walk home. '),
      'On my walk home… what stayed with you?',
    );
  });
}
