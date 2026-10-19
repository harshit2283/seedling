import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/constants/support_links.dart';
import 'package:seedling/features/support/presentation/support_screen.dart';

Future<void> _pump(WidgetTester tester, SupportScreen screen) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the promises and the honest framing', (tester) async {
    await _pump(tester, const SupportScreen());

    expect(find.text('Support Seedling'), findsOneWidget);
    expect(find.text('Seedling is free, and always will be.'), findsOneWidget);
    expect(find.text('No ads, ever.'), findsOneWidget);
    expect(find.text('No tracking and no analytics.'), findsOneWidget);
    expect(find.text('No account needed.'), findsOneWidget);
    expect(find.text('Nothing locked behind payment.'), findsOneWidget);
    expect(find.text('What it is never for'), findsOneWidget);
    expect(find.text('Star or contribute on GitHub'), findsOneWidget);
    expect(find.text('Help translate'), findsOneWidget);
    expect(find.text('Tell a friend'), findsOneWidget);
  });

  testWidgets('hides donation rows while their links are null', (tester) async {
    await _pump(
      tester,
      const SupportScreen(payWhatYouWantUrl: null, githubSponsorsUrl: null),
    );
    expect(find.text('Pay what you want'), findsNothing);
    expect(find.text('GitHub Sponsors'), findsNothing);
  });

  testWidgets('shows donation rows once real links exist', (tester) async {
    await _pump(
      tester,
      const SupportScreen(
        payWhatYouWantUrl: 'https://example.org/pay',
        githubSponsorsUrl: 'https://example.org/sponsor',
      ),
    );
    expect(find.text('Pay what you want'), findsOneWidget);
    expect(find.text('GitHub Sponsors'), findsOneWidget);
  });

  test('source link points at the real repository', () {
    expect(
      SupportLinks.repositoryUrl,
      'https://github.com/harshit2283/seedling',
    );
  });

  testWidgets('transparency section has a calm empty state', (tester) async {
    await _pump(tester, const SupportScreen(fundedSoFar: []));
    expect(find.text('What support has funded'), findsOneWidget);
    expect(find.textContaining('Nothing to report yet.'), findsOneWidget);
  });

  testWidgets('lists funded items when there are some', (tester) async {
    await _pump(
      tester,
      const SupportScreen(fundedSoFar: ['A German translation']),
    );
    expect(find.text('A German translation'), findsOneWidget);
    expect(find.textContaining('Nothing to report yet.'), findsNothing);
  });

  testWidgets('tapping a link copies it and says so', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(tester, const SupportScreen());
    await tester.tap(find.text('Star or contribute on GitHub'));
    await tester.pump();

    expect(copied, SupportLinks.repositoryUrl);
    expect(find.text('Link copied. Paste it in your browser.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
