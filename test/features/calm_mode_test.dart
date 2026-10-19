import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/widget/widget_data_service.dart';
import 'package:seedling/data/models/tree.dart';
import 'package:seedling/features/tree/presentation/animated_tree_visualization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockWidgetService extends Mock implements WidgetDataService {}

void main() {
  group('calmModeProvider', () {
    test('is off by default and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(calmModeProvider), isFalse);
      await container.read(calmModeProvider.notifier).setEnabled(true);
      expect(container.read(calmModeProvider), isTrue);
      expect(prefs.getBool(PrefsKeys.calmModeEnabled), isTrue);
    });

    test('home widgets are told to hide numbers in calm mode', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.calmModeEnabled: true});
      final prefs = await SharedPreferences.getInstance();
      final service = _MockWidgetService();
      when(
        () => service.scheduleUpdate(
          tree: any(named: 'tree'),
          recentEntries: any(named: 'recentEntries'),
          showMemoryPreviews: any(named: 'showMemoryPreviews'),
          calmMode: any(named: 'calmMode'),
        ),
      ).thenReturn(null);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          widgetDataServiceProvider.overrideWithValue(service),
          currentTreeProvider.overrideWithValue(null),
          entriesProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      container.read(widgetAutoUpdateProvider);

      verify(
        () => service.scheduleUpdate(
          tree: any(named: 'tree'),
          recentEntries: any(named: 'recentEntries'),
          showMemoryPreviews: any(named: 'showMemoryPreviews'),
          calmMode: true,
        ),
      ).called(1);
    });

    test('the widget payload carries the calm flag', () {
      final service = WidgetDataService();
      expect(
        service.buildPayload(
          tree: null,
          recentEntries: const [],
          showMemoryPreviews: false,
          calmMode: true,
        )['calmMode'],
        isTrue,
      );
      expect(
        service.buildPayload(
          tree: null,
          recentEntries: const [],
          showMemoryPreviews: false,
        )['calmMode'],
        isFalse,
      );
    });
  });

  group('AnimatedTreeVisualization in calm mode', () {
    Future<void> pumpTree(WidgetTester tester, {required bool details}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedTreeVisualization(
              state: TreeState.sapling,
              progress: 0.4,
              showGrowthDetails: details,
            ),
          ),
        ),
      );
    }

    testWidgets('shows stage and progress by default', (tester) async {
      await pumpTree(tester, details: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sapling'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides stage and progress, keeps the tree', (tester) async {
      await pumpTree(tester, details: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sapling'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
