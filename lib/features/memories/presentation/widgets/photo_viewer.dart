import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/media/file_storage_service.dart';

/// Full-screen photo viewer with pinch-to-zoom
class PhotoViewer extends StatefulWidget {
  final String imagePath;
  final String? title;

  const PhotoViewer({super.key, required this.imagePath, this.title});

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      _transformController.value = _animation!.value;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _showControls = !_showControls);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo with zoom
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 4.0,
              onInteractionEnd: (details) {
                // Reset zoom if scale is close to 1
                if (_transformController.value.getMaxScaleOnAxis() < 1.1) {
                  _resetZoom();
                }
              },
              child: Center(
                child: FutureBuilder<File?>(
                  future: FileStorageService.resolveMediaFile(widget.imagePath),
                  builder: (context, snapshot) {
                    final resolvedFile = snapshot.data;
                    Widget brokenImageFallback() => Icon(
                      PlatformUtils.isIOS
                          ? CupertinoIcons.exclamationmark_triangle
                          : Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    );
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (resolvedFile == null) {
                      return brokenImageFallback();
                    }
                    return Image.file(
                      resolvedFile,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          brokenImageFallback(),
                    );
                  },
                ),
              ),
            ),
            // Top controls
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        // Close button
                        _buildCloseButton(),
                        const Spacer(),
                        if (widget.title != null) ...[
                          Expanded(
                            flex: 2,
                            child: Text(
                              widget.title!,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.xmark,
            color: Colors.white,
            size: 22,
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 22),
      ),
    );
  }

  void _resetZoom() {
    _animation =
        Matrix4Tween(
          begin: _transformController.value,
          end: Matrix4.identity(),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward(from: 0);
  }
}

/// Thumbnail widget for photo entries in memory cards
class PhotoThumbnail extends StatelessWidget {
  final String imagePath;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const PhotoThumbnail({
    super.key,
    required this.imagePath,
    this.size = 60,
    this.borderRadius = 8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<File?>(
        future: FileStorageService.resolveMediaFile(imagePath),
        builder: (context, snapshot) {
          Widget fallback() => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.photo
                  : Icons.broken_image_outlined,
              color: SeedlingColors.textMuted,
              size: size * 0.4,
            ),
          );

          final resolvedFile = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (resolvedFile == null) {
            return fallback();
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              resolvedFile,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
          );
        },
      ),
    );
  }
}
