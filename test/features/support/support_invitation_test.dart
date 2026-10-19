import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/app/router.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/features/support/data/support_invitation_preferences.dart';
import 'package:seedling/features/support/presentation/support_invitation_card.dart';

const _invitationTitle = 'A small note';

Widget _host(SharedPreferences prefs, {Key? key}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(children: [SupportInvitationCard(key: key)]),
        ),
      ),
      GoRoute(
        path: AppRoutes.support,
        builder: (context, state) => const Scaffold(body: Text('support page')),
      ),
    ],
  );
  return ProviderScope(
    key: UniqueKey(),
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SupportInvitationPreferences', () {
    test('claims the showing exactly once', () {
      final invitation = SupportInvitationPreferences(prefs);
      expect(invitation.hasBeenShown, isFalse);
      expect(invitation.claimShowing(), isTrue);
      expect(invitation.claimShowing(), isFalse);
      expect(invitation.claimShowing(), isFalse);
      expect(prefs.getBool(PrefsKeys.supportInvitationShown), isTrue);
    });

    test('a fresh instance sees the earlier claim', () {
      SupportInvitationPreferences(prefs).claimShowing();
      final later = SupportInvitationPreferences(prefs);
      expect(later.hasBeenShown, isTrue);
      expect(later.claimShowing(), isFalse);
    });

    test('a persisted flag from a previous launch suppresses it', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.supportInvitationShown: true,
      });
      final relaunched = await SharedPreferences.getInstance();
      expect(SupportInvitationPreferences(relaunched).claimShowing(), isFalse);
    });
  });

  group('SupportInvitationCard', () {
    testWidgets('shows the first time, never again even if ignored', (
      tester,
    ) async {
      await tester.pumpWidget(_host(prefs, key: const ValueKey('first')));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsOneWidget);

      // Ignore it entirely; remount as if the review were opened again.
      await tester.pumpWidget(_host(prefs, key: const ValueKey('second')));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsNothing);

      await tester.pumpWidget(_host(prefs, key: const ValueKey('third')));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsNothing);
    });

    testWidgets('"Not now" dismisses it forever', (tester) async {
      await tester.pumpWidget(_host(prefs, key: const ValueKey('a')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsNothing);

      await tester.pumpWidget(_host(prefs, key: const ValueKey('b')));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsNothing);
      expect(prefs.getBool(PrefsKeys.supportInvitationShown), isTrue);
    });

    testWidgets('"Tell me more" opens the support page and does not return', (
      tester,
    ) async {
      await tester.pumpWidget(_host(prefs, key: const ValueKey('a')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tell me more'));
      await tester.pumpAndSettle();
      expect(find.text('support page'), findsOneWidget);

      await tester.pumpWidget(_host(prefs, key: const ValueKey('b')));
      await tester.pumpAndSettle();
      expect(find.text(_invitationTitle), findsNothing);
    });
  });
}
