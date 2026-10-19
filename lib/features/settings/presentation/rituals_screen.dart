import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/palette.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/services/providers.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../data/models/ritual.dart';
import 'widgets/ritual_patterns_sheet.dart';
import '../../../app/theme/bar_surfaces.dart';

/// Screen for managing confirmed rituals — pause, archive, delete.
class RitualsScreen extends ConsumerWidget {
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritualsAsync = ref.watch(ritualsStreamProvider);

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: context.groupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: context.barBackground(
            under: context.groupedBackground,
          ),
          border: null,
          middle: const Text('Rituals'),
          previousPageTitle: 'Settings',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => showRitualPatterns(context, ref),
            child: const Text('Patterns'),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ritualsAsync.when(
            data: (rituals) => _buildList(context, ref, rituals),
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (_, _) => const _RitualsUnavailable(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rituals'),
        actions: [
          IconButton(
            tooltip: 'Look for patterns',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => showRitualPatterns(context, ref),
          ),
        ],
      ),
      body: ritualsAsync.when(
        data: (rituals) => _buildList(context, ref, rituals),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _RitualsUnavailable(),
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
                  color: context.palette.primaryContainer.withValues(
                    alpha: 0.28,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.spa_outlined,
                  size: 34,
                  color: context.palette.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No rituals yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seedling quietly notices moments you return to. Confirm one '
                'and it becomes a ritual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 16),
              PlatformUtils.isIOS
                  ? CupertinoButton.filled(
                      onPressed: () => showRitualPatterns(context, ref),
                      child: const Text('Look for patterns'),
                    )
                  : FilledButton(
                      onPressed: () => showRitualPatterns(context, ref),
                      child: const Text('Look for patterns'),
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
          _sectionHeader(context, 'Active'),
          ...active.map((r) => _buildTileMaterial(context, ref, r)),
        ],
        if (paused.isNotEmpty) ...[
          _sectionHeader(context, 'Paused'),
          ...paused.map((r) => _buildTileMaterial(context, ref, r)),
        ],
        if (archived.isNotEmpty) ...[
          _sectionHeader(context, 'Archived'),
          ...archived.map((r) => _buildTileMaterial(context, ref, r)),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.palette.textSecondary,
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
        color: context.palette.primary,
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
        color: context.palette.primary,
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

/// Shown if rituals can't be read. Warm, and never exposes raw errors.
class _RitualsUnavailable extends StatelessWidget {
  const _RitualsUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          "Your rituals couldn't be opened just now. "
          'They are safe. Try again in a moment.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
