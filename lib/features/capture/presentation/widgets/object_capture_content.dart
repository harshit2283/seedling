import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';

/// Content widget for object capture mode
/// Objects require a title and optionally include a photo and story
class ObjectCaptureContent extends ConsumerStatefulWidget {
  final String? initialPhotoPath;
  final String initialTitle;
  final String initialStory;
  final ValueChanged<String?> onPhotoPathChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onStoryChanged;

  const ObjectCaptureContent({
    super.key,
    this.initialPhotoPath,
    required this.initialTitle,
    required this.initialStory,
    required this.onPhotoPathChanged,
    required this.onTitleChanged,
    required this.onStoryChanged,
  });

  @override
  ConsumerState<ObjectCaptureContent> createState() =>
      _ObjectCaptureContentState();
}

class _ObjectCaptureContentState extends ConsumerState<ObjectCaptureContent> {
  String? _photoPath;
  bool _isCapturing = false;
  late TextEditingController _titleController;
  late TextEditingController _storyController;
  final _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _photoPath = widget.initialPhotoPath;
    _titleController = TextEditingController(text: widget.initialTitle);
    _storyController = TextEditingController(text: widget.initialStory);

    // Focus title field if no photo yet
    if (_photoPath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo section
        if (_photoPath != null) _buildPhotoPreview() else _buildPhotoCapture(),
        const SizedBox(height: 16),
        // Title field (required)
        _buildTitleField(),
        const SizedBox(height: 12),
        // Story field (optional)
        _buildStoryField(),
      ],
    );
  }

  Widget _buildPhotoCapture() {
    return GestureDetector(
      onTap: _capturePhoto,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: SeedlingColors.accentObject.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SeedlingColors.accentObject.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: _isCapturing
              ? (PlatformUtils.isIOS
                    ? const CupertinoActivityIndicator()
                    : const CircularProgressIndicator(strokeWidth: 2))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PlatformUtils.isIOS
                          ? CupertinoIcons.camera
                          : Icons.add_a_photo_outlined,
                      size: 32,
                      color: SeedlingColors.accentObject,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add photo (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: SeedlingColors.accentObject,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_photoPath!),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Remove photo button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _removePhoto,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    if (PlatformUtils.isIOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is this object?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SeedlingColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            textCapitalization: TextCapitalization.sentences,
            placeholder: 'e.g., Grandma\'s ring',
            placeholderStyle: TextStyle(
              color: CupertinoColors.placeholderText,
              fontSize: 16,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: SeedlingColors.textPrimary,
            ),
            decoration: BoxDecoration(
              color: SeedlingColors.softCream,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onChanged: widget.onTitleChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is this object?',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: SeedlingColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'e.g., Grandma\'s ring',
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
            filled: true,
            fillColor: SeedlingColors.softCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: widget.onTitleChanged,
        ),
      ],
    );
  }

  Widget _buildStoryField() {
    if (PlatformUtils.isIOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Its story (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SeedlingColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: _storyController,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            placeholder: 'What makes it meaningful?',
            placeholderStyle: TextStyle(
              color: CupertinoColors.placeholderText,
              fontSize: 16,
            ),
            style: const TextStyle(
              fontSize: 16,
              color: SeedlingColors.textPrimary,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
            padding: EdgeInsets.zero,
            onChanged: widget.onStoryChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Its story (optional)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: SeedlingColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _storyController,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'What makes it meaningful?',
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: widget.onStoryChanged,
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.selectionClick();

    final service = ref.read(photoCaptureServiceProvider);
    final result = await service.captureObjectPhoto();

    if (!mounted) return;
    setState(() => _isCapturing = false);

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      setState(() => _photoPath = result.path);
      widget.onPhotoPathChanged(result.path);
    } else if (result.permissionDenied) {
      await _showPermissionDenied();
    } else if (result.error != null) {
      _showError(result.error!);
    }
  }

  void _removePhoto() {
    HapticFeedback.selectionClick();
    setState(() => _photoPath = null);
    widget.onPhotoPathChanged(null);
  }

  Future<void> _showPermissionDenied() async {
    final permissionService = ref.read(permissionServiceProvider);
    final shouldOpenSettings = await permissionService.shouldOpenSettingsFor(
      Permission.camera,
    );
    if (!mounted) return;
    if (shouldOpenSettings) {
      await permissionService.showPermissionDeniedDialog(
        context,
        permissionName: 'Camera',
        purpose: 'capture object photos',
      );
      return;
    }
    _showError('Camera permission was denied');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
