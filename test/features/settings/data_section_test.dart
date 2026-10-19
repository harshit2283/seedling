import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/storage/storage_usage_service.dart';
import 'package:seedling/features/settings/presentation/widgets/data_section.dart';

void main() {
  testWidgets('data section offers Markdown export and journal import', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageUsageProvider.overrideWith(
            (ref) async => const StorageUsage(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSection())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Export as Markdown'), findsOneWidget);
    expect(find.text('Readable files, opens in Obsidian'), findsOneWidget);
    expect(find.text('Import from Day One / Markdown'), findsOneWidget);
    expect(find.text('Day One JSON or Markdown export (.zip)'), findsOneWidget);
  });
}
