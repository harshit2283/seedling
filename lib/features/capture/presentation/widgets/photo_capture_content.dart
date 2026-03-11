import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';

/// Content widget for photo capture mode
class PhotoCaptureContent extends ConsumerStatefulWidget {
  final String? initialPhotoPath;
  final ValueChanged<String?> onPhotoPathChanged;
  final ValueChanged<String> onTextChanged;
  final String text;

  const PhotoCaptureContent({
    super.key,
    this.initialPhotoPath,
    required this.onPhotoPathChanged,
    required this.onTextChanged,
    required this.text,
  });

  @override
  ConsumerState<PhotoCaptureContent> createState() =>
      _PhotoCaptureContentState();
}

class _PhotoCaptureContentState extends ConsumerState<PhotoCaptureContent> {
  String? _photoPath;
  bool _isCapturing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.initialPhotoPath;
    _textController = TextEditingController(text: widget.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_photoPath != null) {
      return _buildPhotoPreview();
    }
    return _buildCaptureOptions();
  }

  Widget _buildCaptureOptions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Text(
          'Add a photo memory',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: SeedlingColors.textPrimary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOptionButton(
              icon: PlatformUtils.isIOS
                  ? CupertinoIcons.camera_fill
                  : Icons.camera_alt,
              label: 'Camera',
              onTap: _captureFromCamera,
            ),
            const SizedBox(width: 32),
            _buildOptionButton(
              icon: PlatformUtils.isIOS
                  ? CupertinoIcons.photo_fill
                  : Icons.photo_library,
              label: 'Library',
              onTap: _pickFromGallery,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isCapturing) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 24,
            height: 24,
            child: PlatformUtils.isIOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCapturing ? null : onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: SeedlingColors.accentPhoto.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SeedlingColors.accentPhoto.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: SeedlingColors.accentPhoto),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SeedlingColors.accentPhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo preview
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_photoPath!),
                height: 200,
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
        ),
        const SizedBox(height: 16),
        // Optional text field
        _buildTextField(),
      ],
    );
  }

  Widget _buildTextField() {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        placeholder: 'Add a note (optional)',
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        style: const TextStyle(fontSize: 16, color: SeedlingColors.textPrimary),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.zero,
        onChanged: widget.onTextChanged,
      );
    }

    return TextField(
      controller: _textController,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Add a note (optional)',
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: widget.onTextChanged,
    );
  }

  Future<void> _captureFromCamera() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.selectionClick();

    final service = ref.read(photoCaptureServiceProvider);
    final result = await service.captureFromCamera();

    if (!mounted) return;
    setState(() => _isCapturing = false);

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      setState(() => _photoPath = result.path);
      widget.onPhotoPathChanged(result.path);
    } else if (result.permissionDenied) {
      await _showPermissionDenied(
        permission: Permission.camera,
        permissionName: 'Camera',
        purpose: 'capture photo memories',
      );
    } else if (result.error != null) {
      _showError(result.error!);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.selectionClick();

    final service = ref.read(photoCaptureServiceProvider);
    final result = await service.pickFromGallery();

    if (!mounted) return;
    setState(() => _isCapturing = false);

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      setState(() => _photoPath = result.path);
      widget.onPhotoPathChanged(result.path);
    } else if (result.permissionDenied) {
      await _showPermissionDenied(
        permission: Permission.photos,
        permissionName: 'Photos',
        purpose: 'pick images from your library',
      );
    } else if (result.error != null) {
      _showError(result.error!);
    }
  }

  void _removePhoto() {
    HapticFeedback.selectionClick();
    setState(() => _photoPath = null);
    widget.onPhotoPathChanged(null);
  }

  Future<void> _showPermissionDenied({
    required Permission permission,
    required String permissionName,
    required String purpose,
  }) async {
    final permissionService = ref.read(permissionServiceProvider);
    final shouldOpenSettings = await permissionService.shouldOpenSettingsFor(
      permission,
    );
    if (!mounted) return;
    if (shouldOpenSettings) {
      await permissionService.showPermissionDeniedDialog(
        context,
        permissionName: permissionName,
        purpose: purpose,
      );
      return;
    }
    _showError('$permissionName permission was denied');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
