import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/providers.dart';
import '../../../data/models/entry.dart';

/// A dedicated gallery view for Object entries — a personal museum.
class ObjectGalleryScreen extends ConsumerWidget {
  const ObjectGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objects = ref.watch(objectEntriesProvider);

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Your Collection'),
          previousPageTitle: 'Settings',
        ),
        child: _buildBody(context, objects),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Collection')),
      body: _buildBody(context, objects),
    );
  }

  Widget _buildBody(BuildContext context, List<Entry> objects) {
    if (objects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 48,
                color: SeedlingColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'No objects yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture something meaningful — a gift, a keepsake, something that tells a story.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isIOS = PlatformUtils.isIOS;
    final borderRadius = BorderRadius.circular(isIOS ? 20 : 12);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: objects.length,
      itemBuilder: (context, index) {
        final entry = objects[index];
        return _ObjectCell(entry: entry, borderRadius: borderRadius);
      },
    );
  }
}

class _ObjectCell extends StatelessWidget {
  const _ObjectCell({required this.entry, required this.borderRadius});

  final Entry entry;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppRoutes.entryRoute(entry.id));
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo or placeholder
            if (entry.hasMedia)
              Image.file(
                File(entry.mediaPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            else
              _placeholder(context),

            // Bottom gradient + title overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: Text(
                  entry.title ?? entry.displayContent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: SeedlingColors.accentObject.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.category_outlined,
          size: 36,
          color: SeedlingColors.accentObject.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
