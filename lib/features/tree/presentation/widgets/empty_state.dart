import 'package:flutter/material.dart';
import '../../../../app/theme/palette.dart';
import '../../../../app/theme/typography.dart';

/// First run: the seed sits above this one line of invitation. The add
/// button below the page does the rest.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            'Every tree begins\nwith one memory.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.textPrimary,
              fontFamily: SeedlingTypography.serifFamily,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What stayed with you today?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
