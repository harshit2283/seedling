import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/services/providers.dart';
import '../../../../data/models/entry.dart';
import 'keepsake_memory_card.dart';

/// "Related memories": a quiet horizontal row of memories that share words,
/// a theme or a moment in time with this one. Renders nothing when there are
/// none, so the page never shows an empty section.
class SimilarMemoriesSection extends ConsumerWidget {
  final int entryId;

  /// Horizontal page padding the header and row align to.
  final double horizontalPadding;

  const SimilarMemoriesSection({
    super.key,
    required this.entryId,
    this.horizontalPadding = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(entryConnectionsProvider(entryId));
    if (connections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: const KeepsakeSectionLabel('Related memories'),
        ),
        const SizedBox(height: 12),
        KeepsakeMemoryRow(
          entries: [for (final c in connections) c.relatedEntry],
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          onOpen: (entry) => _open(context, entry),
        ),
      ],
    );
  }

  void _open(BuildContext context, Entry entry) {
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.entryRoute(entry.id));
    }
  }
}
