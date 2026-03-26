import 'package:flutter/material.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';

/// Empty state shown when no memories have been captured yet
class EmptyState extends StatelessWidget {
  final VoidCallback? onAddTap;

  const EmptyState({super.key, this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(PlatformUtils.isIOS ? 20.0 : 12.0),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SeedlingColors.paleGreen.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 32,
              color: SeedlingColors.leafGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Plant your first memory',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: SeedlingColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'What stayed with you today?\nA moment, a feeling, or a thought.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SeedlingColors.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAddTap != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Memory'),
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.forestGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
