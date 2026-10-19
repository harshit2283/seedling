import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/palette.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../data/support_invitation_preferences.dart';

/// The single, gentle invitation to support Seedling.
///
/// Placed only at the end of a Year in Review — a calm moment the person
/// chose to open. It appears at most once per install: the showing is
/// claimed (persisted) the first time this widget mounts, so it never comes
/// back, whether the person taps "Not now", taps "Tell me more", or ignores
/// it entirely. No counters, no repeat, no guilt.
class SupportInvitationCard extends ConsumerStatefulWidget {
  const SupportInvitationCard({super.key});

  @override
  ConsumerState<SupportInvitationCard> createState() =>
      _SupportInvitationCardState();
}

class _SupportInvitationCardState extends ConsumerState<SupportInvitationCard> {
  late bool _visible;

  @override
  void initState() {
    super.initState();
    final prefs = SupportInvitationPreferences(
      ref.read(sharedPreferencesProvider),
    );
    _visible = prefs.claimShowing();
  }

  void _dismiss() {
    HapticFeedback.selectionClick();
    setState(() => _visible = false);
  }

  void _learnMore() {
    HapticFeedback.selectionClick();
    setState(() => _visible = false);
    context.push(AppRoutes.support);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: _visible ? _buildCard(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = context.palette.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GlassContainer(
        borderRadius: PlatformUtils.isIOS ? 20 : 12,
        opacity: 0.75,
        border: Border.all(color: context.palette.divider),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A small note', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Seedling is free and open source, made by one person. '
                'Nothing is locked, and nothing will be. If this year of '
                'memories meant something to you, you can help keep it '
                'growing. Only if you want to.',
                style: textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: context.palette.textMuted,
                    ),
                    child: const Text('Not now'),
                  ),
                  TextButton(
                    onPressed: _learnMore,
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: const Text('Tell me more'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
