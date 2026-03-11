import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:seedling/data/models/entry.dart';
import 'package:seedling/features/memories/presentation/widgets/memory_share_sheet.dart';
import 'package:share_plus/share_plus.dart';

class _MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProviderPlatform(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  late String tempDirPath;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    originalPathProvider = PathProviderPlatform.instance;
    tempDirPath = await Directory.systemTemp
        .createTemp('seedling_memory_share_test_')
        .then((dir) => dir.path);
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDirPath);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);

    final tempDir = Directory(tempDirPath);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }

    PathProviderPlatform.instance = originalPathProvider;
  });

  testWidgets(
    'opens in Cupertino popup without Material localization errors',
    (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => showMemoryShareSheet(
                context,
                Entry.line(text: 'A quiet morning'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Share memory'), findsWidgets);
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS}),
  );

  test(
    'share helper passes a non-zero iOS share origin to share_plus',
    () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            capturedCall = call;
            return '';
          });

      final shareFile = File('$tempDirPath/share-card.png');
      await shareFile.writeAsBytes(const <int>[1, 2, 3, 4]);

      await shareMemoryFiles(
        files: [XFile(shareFile.path)],
        text: 'Posting this to the family group\n\nShared from Seedling',
        shareOrigin: const Rect.fromLTWH(12, 24, 180, 240),
      );

      expect(capturedCall, isNotNull);
      expect(capturedCall?.method, 'shareFiles');

      final arguments = capturedCall!.arguments as Map<dynamic, dynamic>;
      expect((arguments['paths'] as List).single, shareFile.path);
      expect(arguments['originX'], 12.0);
      expect(arguments['originY'], 24.0);
      expect(arguments['originWidth'], 180.0);
      expect(arguments['originHeight'], 240.0);
      expect(arguments['text'], contains('Posting this to the family group'));
      expect(arguments['text'], contains('Shared from Seedling'));
    },
  );
}
