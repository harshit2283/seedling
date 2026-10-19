import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/services/providers.dart';
import 'settings_helpers.dart';
import 'settings_tiles.dart';

/// "Your memories": the collections inside the tree, and taking care of the
/// memories themselves (export, storage, recently deleted).
class MemoriesSection extends ConsumerWidget {
  const MemoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(storageUsageProvider);
    final deletedCount = ref.watch(deletedEntriesProvider).length;
    final capsules = ref.watch(capsulesProvider);
    final sealed = capsules.where((c) => c.isLocked).length;
    final storageIcon = adaptiveIcon(
      CupertinoIcons.chart_pie,
      Icons.pie_chart_outline,
    );

    return SettingsGroup(
      title: 'Your memories',
      children: [
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.gift, Icons.hourglass_empty),
          title: 'Memory capsules',
          value: sealed == 0 ? null : '$sealed sealed',
          onTap: () => context.push(AppRoutes.capsules),
        ),
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.cube, Icons.category_outlined),
          title: 'Object collection',
          onTap: () => context.push(AppRoutes.collection),
        ),
        SettingsRow(
          icon: adaptiveIcon(
            CupertinoIcons.circle_grid_hex,
            Icons.bubble_chart_outlined,
          ),
          title: 'Themes',
          subtitle: 'What your memories tend to hold',
          onTap: () => context.push(AppRoutes.themeInsights),
        ),
        SettingsRow(
          icon: adaptiveIcon(CupertinoIcons.repeat, Icons.autorenew),
          title: 'Rituals',
          subtitle: 'Moments you keep coming back to',
          onTap: () => context.push(AppRoutes.rituals),
        ),
        SettingsRow(
          key: const ValueKey('settings-export-import'),
          icon: adaptiveIcon(
            CupertinoIcons.arrow_up_arrow_down,
            Icons.import_export,
          ),
          title: 'Export & import',
          subtitle: 'Backups, ZIP, Markdown, Day One',
          onTap: () => context.push(AppRoutes.settingsData),
        ),
        storageAsync.when(
          data: (storage) => SettingsRow(
            icon: storageIcon,
            title: 'Storage',
            value: storage.totalFormatted,
            onTap: () => showStorageDetails(context, storage),
          ),
          loading: () =>
              SettingsRow(icon: storageIcon, title: 'Storage', isLoading: true),
          error: (_, _) => SettingsRow(
            icon: storageIcon,
            title: 'Storage',
            value: 'Unavailable',
          ),
        ),
        SettingsRow(
          icon: AdaptiveIcons.trash,
          title: 'Recently deleted',
          subtitle: 'Kept for 30 days, then let go',
          value: deletedCount == 0 ? null : '$deletedCount',
          onTap: () => context.push(AppRoutes.deletedEntries),
        ),
      ],
    );
  }
}
