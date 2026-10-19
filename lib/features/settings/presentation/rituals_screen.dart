import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../core/presentation/seedling_iconography.dart';
import '../../../core/services/ai/models/ritual_candidate.dart';
import '../../../core/services/providers.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/ritual.dart';
import '../domain/ritual_memory_groups.dart';
import 'widgets/ritual_patterns_sheet.dart';

/// One line that explains what a ritual is, shown at the top of the screen.
const String ritualsExplainer =
    'Rituals are the moments you return to, like a Sunday coffee or an '
    'evening walk. Each time you save one with the same name, it gathers here.';

/// The person's ritual memories, grouped by the ritual's name.
final ritualMemoryGroupsProvider =
    Provider.autoDispose<List<RitualMemoryGroup>>(
      (ref) => groupRitualMemories(ref.watch(allEntriesProvider)),
    );

/// The rituals the person keeps: their ritual memories grouped by name
/// (recurring moments), the patterns they chose to keep, and, below,
/// patterns Seedling has noticed offered as gentle suggestions.
class RitualsScreen extends ConsumerWidget {
  const RitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ritualsAsync = ref.watch(ritualsStreamProvider);

    final body = ritualsAsync.when(
      data: (rituals) => _RitualsBody(kept: rituals),
      loading: () => Center(
        child: PlatformUtils.isIOS
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      ),
      error: (_, _) => const _RitualsUnavailable(),
    );

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          border: null,
          middle: Text('Rituals'),
          previousPageTitle: 'Settings',
        ),
        child: SafeArea(
          top: false,
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: body,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rituals')),
      body: body,
    );
  }
}

class _RitualsBody extends ConsumerWidget {
  final List<Ritual> kept;

  const _RitualsBody({required this.kept});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(ritualMemoryGroupsProvider);
    final suggestions = _freshSuggestions(
      ref.watch(ritualCandidatesProvider),
      groups,
      kept,
    );
    final keptVisible = kept
        .where((r) => r.status != RitualStatus.archived)
        .toList();
    final archived = kept
        .where((r) => r.status == RitualStatus.archived)
        .toList();
    final isEmpty = groups.isEmpty && kept.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            ritualsExplainer,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: context.palette.textSecondary,
            ),
          ),
        ),
        if (isEmpty) const _EmptyRituals(),
        if (groups.isNotEmpty)
          _Section(
            title: 'Your rituals',
            children: [
              for (final group in groups) _RitualGroupTile(group: group),
            ],
          ),
        if (keptVisible.isNotEmpty)
          _Section(
            title: 'Kept from patterns',
            children: [
              for (final ritual in keptVisible) _KeptRitualTile(ritual: ritual),
            ],
          ),
        if (archived.isNotEmpty)
          _Section(
            title: 'Resting',
            children: [
              for (final ritual in archived) _KeptRitualTile(ritual: ritual),
            ],
          ),
        if (suggestions.isNotEmpty)
          _Section(
            title: 'Seedling noticed',
            footer:
                'Only suggestions. Nothing becomes a ritual unless you keep it.',
            children: [
              for (final candidate in suggestions.take(3))
                _SuggestionTile(candidate: candidate),
              if (suggestions.length > 3)
                _PlainTile(
                  title: 'See all patterns',
                  onTap: () => showRitualPatterns(context, ref),
                ),
            ],
          ),
      ],
    );
  }

  /// Hides patterns that are already rituals: ones the person kept, and
  /// ones that are really their own named ritual memories.
  List<RitualCandidate> _freshSuggestions(
    List<RitualCandidate> candidates,
    List<RitualMemoryGroup> groups,
    List<Ritual> kept,
  ) {
    final keptSignatures = kept.map((r) => r.signature).toSet();
    final ritualTexts = <String>{
      for (final g in groups) ...[
        ritualKey(g.title),
        for (final e in g.occurrences) ritualKey(e.displayContent),
      ],
    };
    return candidates
        .where((c) => !keptSignatures.contains(c.signature))
        .where((c) => !ritualTexts.contains(ritualKey(c.sampleText)))
        .toList();
  }
}

String _shortDate(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year
      ? DateFormat('d MMM').format(date)
      : DateFormat('d MMM y').format(date);
}

String _timesLabel(int count) => switch (count) {
  1 => 'Once',
  2 => 'Twice',
  _ => '$count times',
};

/// Adaptive grouped section: inset-grouped on iOS, a quiet header on Android.
class _Section extends StatelessWidget {
  final String title;
  final String? footer;
  final List<Widget> children;

  const _Section({required this.title, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: Text(title),
        footer: footer == null
            ? null
            : Text(
                footer!,
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textMuted,
                ),
              ),
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
            ),
          ),
        ),
        ...children,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              footer!,
              style: TextStyle(fontSize: 12, color: context.palette.textMuted),
            ),
          ),
      ],
    );
  }
}

class _RitualGroupTile extends StatelessWidget {
  final RitualMemoryGroup group;

  const _RitualGroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final subtitle = group.count == 1
        ? 'Once · ${_shortDate(group.lastAt)}'
        : '${_timesLabel(group.count)} · last ${_shortDate(group.lastAt)}';
    void open() {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(
        PlatformUtils.isIOS
            ? CupertinoPageRoute<void>(
                builder: (_) => RitualOccurrencesScreen(title: group.title),
              )
            : MaterialPageRoute<void>(
                builder: (_) => RitualOccurrencesScreen(title: group.title),
              ),
      );
    }

    final leading = Icon(
      PlatformUtils.isIOS ? CupertinoIcons.repeat : Icons.autorenew,
      color: context.palette.accentRitual,
    );
    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        leading: leading,
        title: Text(group.title),
        subtitle: Text(subtitle),
        trailing: const CupertinoListTileChevron(),
        onTap: open,
      );
    }
    return ListTile(
      leading: leading,
      title: Text(group.title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: open,
    );
  }
}

class _SuggestionTile extends ConsumerWidget {
  final RitualCandidate candidate;

  const _SuggestionTile({required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucket = candidate.signature.split(':').first;
    final when = switch (bucket) {
      'morning' => 'Often in the morning',
      'afternoon' => 'Often in the afternoon',
      'evening' => 'Often in the evening',
      _ => 'Often at night',
    };
    final title = candidate.sampleText.trim().split('\n').first;
    final subtitle = '$when · ${_timesLabel(candidate.occurrences)}';
    void keep() => confirmRitualCandidate(context, ref, candidate);

    final leading = Icon(
      PlatformUtils.isIOS ? CupertinoIcons.sparkles : Icons.auto_awesome,
      color: context.palette.textMuted,
    );
    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        leading: leading,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: keep,
          child: const Text('Keep'),
        ),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: TextButton(onPressed: keep, child: const Text('Keep')),
    );
  }
}

class _PlainTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _PlainTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        title: Text(title),
        trailing: const CupertinoListTileChevron(),
        onTap: onTap,
      );
    }
    return ListTile(title: Text(title), onTap: onTap);
  }
}

class _EmptyRituals extends StatelessWidget {
  const _EmptyRituals();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.palette.primaryContainer.withValues(alpha: 0.28),
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
            'Choose Ritual when you capture a memory and give it a name.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A pattern the person kept, with pause, rest and remove actions.
class _KeptRitualTile extends ConsumerWidget {
  final Ritual ritual;

  const _KeptRitualTile({required this.ritual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysSince = ritual.daysSinceLastObserved;
    final subtitle = daysSince != null
        ? 'Last noticed $daysSince day${daysSince == 1 ? '' : 's'} ago · '
              '${ritual.cadenceDescription}'
        : '${ritual.cadenceDescription} · '
              '${_timesLabel(ritual.occurrenceCount).toLowerCase()}';
    final leading = Icon(
      SeedlingIconography.ritualStatusIcon(ritual.status),
      color: context.palette.primary,
    );

    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        leading: leading,
        title: Text(ritual.name),
        subtitle: Text(subtitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis),
          onPressed: () => _showActions(context, ref),
        ),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(ritual.name),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          for (final a in _actions())
            PopupMenuItem(value: a.$1, child: Text(a.$2)),
        ],
        onSelected: (value) => _handle(ref, value),
      ),
    );
  }

  List<(String, String)> _actions() => [
    if (ritual.status == RitualStatus.active) ('pause', 'Pause'),
    if (ritual.status == RitualStatus.paused) ('activate', 'Resume'),
    if (ritual.status != RitualStatus.archived) ('archive', 'Let it rest'),
    if (ritual.status == RitualStatus.archived) ('activate', 'Bring back'),
    ('delete', 'Remove'),
  ];

  Future<void> _handle(WidgetRef ref, String action) async {
    final service = ref.read(ritualServiceProvider);
    switch (action) {
      case 'pause':
        await service.pauseRitual(ritual.id);
      case 'activate':
        await service.activateRitual(ritual.id);
      case 'archive':
        await service.archiveRitual(ritual.id);
      case 'delete':
        await service.deleteRitual(ritual.id);
        HapticFeedback.mediumImpact();
        return;
    }
    HapticFeedback.selectionClick();
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(ritual.name),
        actions: [
          for (final a in _actions())
            CupertinoActionSheetAction(
              isDestructiveAction: a.$1 == 'delete',
              onPressed: () {
                Navigator.pop(ctx);
                _handle(ref, a.$1);
              },
              child: Text(a.$2),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

/// Every time a ritual has come back, newest first.
class RitualOccurrencesScreen extends ConsumerWidget {
  final String title;

  const RitualOccurrencesScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ritualKey(title);
    final groups = ref.watch(ritualMemoryGroupsProvider);
    final group = groups.where((g) => ritualKey(g.title) == key).firstOrNull;
    final occurrences = group?.occurrences ?? const <Entry>[];

    final list = ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (group != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              group.count == 1
                  ? 'Once so far, on ${_shortDate(group.firstAt)}.'
                  : '${_timesLabel(group.count)} since '
                        '${_shortDate(group.firstAt)}.',
              style: TextStyle(
                fontSize: 15,
                color: context.palette.textSecondary,
              ),
            ),
          ),
        _Section(
          title: 'Each time',
          children: [
            for (final entry in occurrences)
              _OccurrenceTile(entry: entry, ritualTitle: title),
          ],
        ),
      ],
    );

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          border: null,
          middle: Text(title),
          previousPageTitle: 'Rituals',
        ),
        child: SafeArea(
          top: false,
          child: DefaultTextStyle(
            style: CupertinoTheme.of(context).textTheme.textStyle,
            child: list,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: list,
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  final Entry entry;
  final String ritualTitle;

  const _OccurrenceTile({required this.entry, required this.ritualTitle});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, d MMMM y').format(entry.createdAt);
    final text = entry.text?.trim() ?? '';
    final note = text.isEmpty || ritualKey(text) == ritualKey(ritualTitle)
        ? null
        : text;
    void open() => context.push(AppRoutes.entryRoute(entry.id));

    if (PlatformUtils.isIOS) {
      return CupertinoListTile(
        title: Text(date),
        subtitle: note == null
            ? null
            : Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const CupertinoListTileChevron(),
        onTap: open,
      );
    }
    return ListTile(
      title: Text(date),
      subtitle: note == null
          ? null
          : Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: open,
    );
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
