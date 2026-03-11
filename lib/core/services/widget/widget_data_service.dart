import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/tree.dart';

/// Service for syncing data to home screen widgets (iOS + Android)
///
/// Widgets display tree state, entry count, and optionally recent memories.
/// Data is stored in platform-specific shared storage:
/// - iOS: App Group UserDefaults
/// - Android: SharedPreferences
class WidgetDataService {
  // Widget identifiers
  static const String _iOSWidgetName = 'SeedlingWidget';
  static const String _androidWidgetProvider =
      'com.twotwoeightthreelabs.seedling.SeedlingWidgetProvider';

  // App Group for iOS (must match Xcode configuration)
  static const String _iOSAppGroup = 'group.com.seedling.seedling';

  /// Initialize the widget service
  Future<void> init() async {
    // Set the App Group for iOS
    await HomeWidget.setAppGroupId(_iOSAppGroup);
  }

  /// Update widget data with current tree and recent entries
  ///
  /// Call this whenever entries are added/deleted or tree state changes.
  Future<void> updateWidgetData({
    required Tree? tree,
    required List<Entry> recentEntries,
    required bool showMemoryPreviews,
  }) async {
    // Tree data
    final treeState = tree?.state.name ?? 'seed';
    final entryCount = tree?.entryCount ?? 0;
    final progress = tree?.progressToNextStage ?? 0.0;
    final stateName = tree?.stateName ?? 'Seed';
    final stateDescription =
        tree?.stateDescription ?? 'Every memory starts as a seed';

    // Tree emoji based on state
    final treeEmoji = _getTreeEmoji(tree?.state ?? TreeState.seed);

    // Recent entries (up to 3 for large widget)
    final recentEntriesJson = jsonEncode(
      showMemoryPreviews
          ? recentEntries
                .take(3)
                .map(
                  (e) => {
                    'id': e.id,
                    'preview': _getEntryPreview(e),
                    'type': e.type.name,
                    'date': e.createdAt.toIso8601String(),
                  },
                )
                .toList()
          : const <Map<String, dynamic>>[],
    );

    // Save all widget data
    await Future.wait([
      HomeWidget.saveWidgetData('treeState', treeState),
      HomeWidget.saveWidgetData('treeEmoji', treeEmoji),
      HomeWidget.saveWidgetData('entryCount', entryCount),
      HomeWidget.saveWidgetData('progress', progress),
      HomeWidget.saveWidgetData('stateName', stateName),
      HomeWidget.saveWidgetData('stateDescription', stateDescription),
      HomeWidget.saveWidgetData('recentEntries', recentEntriesJson),
      HomeWidget.saveWidgetData(
        'lastUpdated',
        DateTime.now().toIso8601String(),
      ),
    ]);

    // Trigger widget refresh on both platforms
    await _updateWidgets();
  }

  /// Get tree emoji for current state
  String _getTreeEmoji(TreeState state) {
    switch (state) {
      case TreeState.seed:
        return '🌱';
      case TreeState.sprout:
        return '🌿';
      case TreeState.sapling:
        return '🌳';
      case TreeState.youngTree:
        return '🌲';
      case TreeState.matureTree:
        return '🌴';
      case TreeState.ancientTree:
        return '🎄';
    }
  }

  /// Get a short preview of an entry for widget display
  String _getEntryPreview(Entry entry) {
    // Priority: title > text > type name
    if (entry.title != null && entry.title!.isNotEmpty) {
      return _truncate(entry.title!, 40);
    }
    if (entry.text != null && entry.text!.isNotEmpty) {
      return _truncate(entry.text!, 40);
    }
    // Fallback to a human-readable type label.
    return _getTypeLabel(entry.type);
  }

  String _getTypeLabel(EntryType type) {
    switch (type) {
      case EntryType.line:
        return 'A thought';
      case EntryType.photo:
        return 'Photo memory';
      case EntryType.voice:
        return 'Voice memo';
      case EntryType.object:
        return 'Treasured object';
      case EntryType.fragment:
        return 'Fragment';
      case EntryType.ritual:
        return 'Ritual';
      case EntryType.release:
        return 'Release';
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  /// Trigger widget refresh on both platforms
  Future<void> _updateWidgets() async {
    try {
      // iOS: Update all widget configurations
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: _androidWidgetProvider,
      );
    } catch (e) {
      // Widget update may fail if widget not added to home screen
      // This is expected behavior, not an error
    }
  }

  /// Handle widget tap - returns the URI if a deep link was triggered
  Future<Uri?> getInitialLaunchUri() async {
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  /// Stream of URIs when widget is tapped while app is running
  Stream<Uri?> get widgetTapStream => HomeWidget.widgetClicked;

  /// Register a callback for widget interactions
  /// Use this to handle "quick capture" button on widget
  Future<void> registerInteractivity() async {
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }
}

/// Global callback for widget interactivity (required by home_widget)
/// This runs in a separate isolate, so keep it lightweight
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  // The URI will be handled by the main app when it opens
  // Widget buttons use URIs like:
  // - seedling://home (open app)
  // - seedling://capture (open capture sheet)
}
