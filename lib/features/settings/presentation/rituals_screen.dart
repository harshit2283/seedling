import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/services/providers.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../data/models/ritual.dart';

/// Screen for managing confirmed rituals — pause, archive, delete.
class RitualsScreen extends ConsumerWidget {
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritualsAsync = ref.watch(ritualsStreamProvider);

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          border: null,
          middle: Text('Rituals'),
        ),
        child: SafeArea(
          top: false,
          child: ritualsAsync.when(
            data: (rituals) => _buildList(context, ref, rituals),
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rituals')),
      body: ritualsAsync.when(
        data: (rituals) => _buildList(context, ref, rituals),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Ritual> rituals) {
    if (rituals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SeedlingColors.paleGreen.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  size: 34,
                  color: SeedlingColors.forestGreen,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No rituals yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Patterns become rituals once you confirm them in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SeedlingColors.textSecondary),
              ),
              const SizedBox(height: 16),
              PlatformUtils.isIOS
                  ? CupertinoButton.filled(
                      onPressed: () => context.pop(),
                      child: const Text('Back to Settings'),
                    )
                  : FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back to Settings'),
                    ),
            ],
          ),
        ),
      );
    }

    final active = rituals
        .where((r) => r.statusIndex == RitualStatus.active.index)
        .toList();
    final paused = rituals
        .where((r) => r.statusIndex == RitualStatus.paused.index)
        .toList();
    final archived = rituals
        .where((r) => r.statusIndex == RitualStatus.archived.index)
        .toList();

    if (PlatformUtils.isIOS) {
      return ListView(
        children: [
          if (active.isNotEmpty) ...[
            CupertinoListSection.insetGrouped(
              header: const Text('Active'),
              children: active
                  .map((r) => _buildTileIOS(context, ref, r))
                  .toList(),
            ),
          ],
          if (paused.isNotEmpty) ...[
            CupertinoListSection.insetGrouped(
              header: const Text('Paused'),
              children: paused
                  .map((r) => _buildTileIOS(context, ref, r))
                  .toList(),
            ),
          ],
          if (archived.isNotEmpty) ...[
            CupertinoListSection.insetGrouped(
              header: const Text('Archived'),
              children: archived
                  .map((r) => _buildTileIOS(context, ref, r))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
        ],
      );
    }

    return ListView(
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('Active'),
          ...active.map((r) => _buildTileMaterial(context, ref, r)),
        ],
        if (paused.isNotEmpty) ...[
          _sectionHeader('Paused'),
          ...paused.map((r) => _buildTileMaterial(context, ref, r)),
        ],
        if (archived.isNotEmpty) ...[
          _sectionHeader('Archived'),
          ...archived.map((r) => _buildTileMaterial(context, ref, r)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: SeedlingColors.textSecondary,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _buildTileIOS(BuildContext context, WidgetRef ref, Ritual ritual) {
    final daysSince = ritual.daysSinceLastObserved;
    final subtitle = daysSince != null
        ? 'Last observed $daysSince day${daysSince == 1 ? '' : 's'} ago · ${ritual.cadenceDescription}'
        : '${ritual.cadenceDescription} · ${ritual.occurrenceCount} times';

    return CupertinoListTile(
      leading: Icon(
        SeedlingIconography.ritualStatusIcon(ritual.status),
        color: SeedlingColors.forestGreen,
      ),
      title: Text(ritual.name),
      subtitle: Text(subtitle),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.ellipsis),
        onPressed: () => _showActions(context, ref, ritual),
      ),
    );
  }

  Widget _buildTileMaterial(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
  ) {
    final daysSince = ritual.daysSinceLastObserved;
    final subtitle = daysSince != null
        ? 'Last observed $daysSince day${daysSince == 1 ? '' : 's'} ago · ${ritual.cadenceDescription}'
        : '${ritual.cadenceDescription} · ${ritual.occurrenceCount} times';

    return ListTile(
      leading: Icon(
        SeedlingIconography.ritualStatusIcon(ritual.status),
        color: SeedlingColors.forestGreen,
      ),
      title: Text(ritual.name),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => _menuItems(ritual),
        onSelected: (value) => _handleAction(context, ref, ritual, value),
      ),
    );
  }

  List<PopupMenuItem<String>> _menuItems(Ritual ritual) {
    final items = <PopupMenuItem<String>>[];
    if (ritual.status == RitualStatus.active) {
      items.add(const PopupMenuItem(value: 'pause', child: Text('Pause')));
    }
    if (ritual.status == RitualStatus.paused) {
      items.add(const PopupMenuItem(value: 'activate', child: Text('Resume')));
    }
    if (ritual.status != RitualStatus.archived) {
      items.add(const PopupMenuItem(value: 'archive', child: Text('Archive')));
    }
    if (ritual.status == RitualStatus.archived) {
      items.add(const PopupMenuItem(value: 'activate', child: Text('Restore')));
    }
    items.add(const PopupMenuItem(value: 'delete', child: Text('Delete')));
    return items;
  }

  void _showActions(BuildContext context, WidgetRef ref, Ritual ritual) {
    final actions = <CupertinoActionSheetAction>[];
    final service = ref.read(ritualServiceProvider);

    if (ritual.status == RitualStatus.active) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            await service.pauseRitual(ritual.id);
            HapticFeedback.selectionClick();
          },
          child: const Text('Pause'),
        ),
      );
    }
    if (ritual.status == RitualStatus.paused) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            await service.activateRitual(ritual.id);
            HapticFeedback.selectionClick();
          },
          child: const Text('Resume'),
        ),
      );
    }
    if (ritual.status != RitualStatus.archived) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            await service.archiveRitual(ritual.id);
            HapticFeedback.selectionClick();
          },
          child: const Text('Archive'),
        ),
      );
    }
    if (ritual.status == RitualStatus.archived) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            await service.activateRitual(ritual.id);
            HapticFeedback.selectionClick();
          },
          child: const Text('Restore'),
        ),
      );
    }
    actions.add(
      CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () async {
          Navigator.pop(context);
          await service.deleteRitual(ritual.id);
          HapticFeedback.mediumImpact();
        },
        child: const Text('Delete'),
      ),
    );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(ritual.name),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    String action,
  ) {
    final service = ref.read(ritualServiceProvider);
    switch (action) {
      case 'pause':
        service.pauseRitual(ritual.id);
        break;
      case 'activate':
        service.activateRitual(ritual.id);
        break;
      case 'archive':
        service.archiveRitual(ritual.id);
        break;
      case 'delete':
        service.deleteRitual(ritual.id);
        break;
    }
  }
}
