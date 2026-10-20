import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/constants/support_links.dart';
import 'package:seedling/core/platform/platform_utils.dart';
import 'package:seedling/features/support/presentation/support_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

Future<void> _pump(
  WidgetTester tester,
  SupportScreen screen, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: theme, home: screen));
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
    expect(find.text('Star on GitHub'), findsOneWidget);
    expect(find.text('Contribute'), findsOneWidget);
    expect(find.text('Report a bug'), findsOneWidget);
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
    // An honest line instead of an empty promise.
    expect(find.text(donationLinksPendingNote), findsOneWidget);
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
    expect(find.text(donationLinksPendingNote), findsNothing);
  });

  testWidgets('each help row copies its own link without a browser', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeLauncher(canOpen: false);
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    final copied = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String?);
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
    for (final row in ['Contribute', 'Report a bug', 'Help translate']) {
      await tester.tap(find.text(row));
      await tester.pump();
    }
    expect(copied, [
      SupportLinks.contributingUrl,
      SupportLinks.issuesUrl,
      SupportLinks.translateUrl,
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 4));
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

  testWidgets('tapping a link copies it when no browser can open it', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeLauncher(canOpen: false);
    addTearDown(() => UrlLauncherPlatform.instance = previous);
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
    await tester.tap(find.text('Star on GitHub'));
    await tester.pump();

    expect(copied, SupportLinks.repositoryUrl);
    expect(find.text('Link copied. Paste it in your browser.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('iOS dark: nav bar fill is dark, not light grey', (tester) async {
    PlatformUtils.debugIsIOSOverride = true;
    addTearDown(() => PlatformUtils.debugIsIOSOverride = null);
    await _pump(tester, const SupportScreen(), theme: SeedlingTheme.dark);
    final bar = tester.widget<CupertinoNavigationBar>(
      find.byType(CupertinoNavigationBar),
    );
    expect(bar.backgroundColor!.computeLuminance(), lessThan(0.05));
  });

  testWidgets('a link opens in the browser when it can', (tester) async {
    final previous = UrlLauncherPlatform.instance;
    final fake = _FakeLauncher();
    UrlLauncherPlatform.instance = fake;
    addTearDown(() => UrlLauncherPlatform.instance = previous);

    await _pump(tester, const SupportScreen());
    await tester.tap(find.text('Star on GitHub'));
    await tester.pump();

    expect(fake.launched, [SupportLinks.repositoryUrl]);
    expect(find.text('Link copied. Paste it in your browser.'), findsNothing);
  });
}

class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeLauncher({this.canOpen = true});

  final bool canOpen;
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return canOpen;
  }
}
