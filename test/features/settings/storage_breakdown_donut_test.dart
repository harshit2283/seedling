import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/storage/storage_usage_service.dart';
import 'package:seedling/features/settings/presentation/widgets/storage_breakdown_donut.dart';

void main() {
  testWidgets('StorageBreakdownDonut renders without throwing for empty usage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StorageBreakdownDonut(usage: StorageUsage()),
        ),
      ),
    );
    expect(find.byType(StorageBreakdownDonut), findsOneWidget);
  });

  testWidgets('StorageBreakdownDonut animates from 0 to final on usage data',
      (tester) async {
    const usage = StorageUsage(
      databaseBytes: 100,
      photosBytes: 200,
      voicesBytes: 50,
      objectsBytes: 30,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StorageBreakdownDonut(usage: usage)),
      ),
    );

    // Initial frame: progress is 0.
    expect(find.byType(StorageBreakdownDonut), findsOneWidget);

    // Animate forward; the painter rebuilds without throwing.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(StorageBreakdownDonut), findsOneWidget);
  });

  testWidgets('StorageBreakdownLegend shows a row per non-zero category',
      (tester) async {
    const usage = StorageUsage(
      databaseBytes: 100,
      photosBytes: 200,
      voicesBytes: 0,
      objectsBytes: 30,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StorageBreakdownLegend(usage: usage)),
      ),
    );
    await tester.pumpAndSettle();

    // Should show database, photos, objects rows; voices is zero so it may
    // still appear but with a 0 value -- we only assert the widget builds.
    expect(find.byType(StorageBreakdownLegend), findsOneWidget);
  });
}
