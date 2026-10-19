import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/app/theme/palette.dart';
import 'package:seedling/app/theme/seedling_theme.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/sync/sync_engine.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:seedling/features/settings/presentation/widgets/sync_status_tile.dart';

/// The engine as the tile sees it: only its quarantine count matters.
class _Engine extends Mock implements SyncEngine {
  _Engine(this.count);
  int count;

  @override
  int get quarantineCount => count;
}

Future<_Engine> _metadataWith(int quarantined) async => _Engine(quarantined);

Widget _host(_Engine engine) {
  return ProviderScope(
    overrides: [
      syncEngineProvider.overrideWithValue(engine),
      syncStateProvider.overrideWith((ref) => Stream.value(SyncState.idle)),
    ],
    child: MaterialApp(
      theme: SeedlingTheme.light,
      home: const Scaffold(body: SyncQuarantineNotice()),
    ),
  );
}

void main() {
  testWidgets('shows nothing when no changes are set aside', (tester) async {
    final metadata = await _metadataWith(0);
    await tester.pumpWidget(_host(metadata));
    await tester.pump();

    expect(find.textContaining("couldn't be read"), findsNothing);
    expect(find.text('Why?'), findsNothing);
  });

  testWidgets('shows the engine quarantine count with a calm explanation', (
    tester,
  ) async {
    final metadata = await _metadataWith(3);
    await tester.pumpWidget(_host(metadata));
    await tester.pump();

    expect(
      find.text(
        "3 changes from another device couldn't be read — re-enter your "
        'passphrase on that device.',
      ),
      findsOneWidget,
    );
    // Calm, not alarming: secondary palette text, not the error colour.
    final text = tester.widget<Text>(find.text(syncQuarantineMessage(3)));
    expect(text.style?.color, SeedlingPalette.light.textSecondary);
    expect(text.style?.color, isNot(SeedlingPalette.light.error));

    // The "Why?" target is 44x44 and explains via a message.
    final target = find.ancestor(
      of: find.text('Why?'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(target.first), const Size(44, 44));
    await tester.tap(find.text('Why?'));
    await tester.pump();
    expect(find.text(syncQuarantineDetail), findsOneWidget);
  });

  testWidgets('singular copy for one change', (tester) async {
    final metadata = await _metadataWith(1);
    await tester.pumpWidget(_host(metadata));
    await tester.pump();

    expect(find.text(syncQuarantineMessage(1)), findsOneWidget);
    expect(syncQuarantineMessage(1), startsWith('1 change from'));
  });

  testWidgets('updates when a pull changes the quarantine', (tester) async {
    final metadata = await _metadataWith(2);
    final states = StreamController<SyncState>();
    addTearDown(states.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncEngineProvider.overrideWithValue(metadata),
          syncStateProvider.overrideWith((ref) => states.stream),
        ],
        child: MaterialApp(
          theme: SeedlingTheme.light,
          home: const Scaffold(body: SyncQuarantineNotice()),
        ),
      ),
    );
    states.add(SyncState.idle);
    await tester.pump();
    expect(find.text(syncQuarantineMessage(2)), findsOneWidget);

    // A later pull reads them all: the notice goes away.
    metadata.count = 0;
    states.add(SyncState.merging);
    await tester.pump();
    states.add(SyncState.idle);
    await tester.pump();
    expect(find.textContaining("couldn't be read"), findsNothing);
  });
}
