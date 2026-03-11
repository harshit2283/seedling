import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../platform/platform_utils.dart';

/// Unified service for handling runtime permissions
class PermissionService {
  /// Request camera permission
  /// Returns true if granted
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  /// Returns true if granted
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request photo library permission
  /// Returns true if granted
  Future<bool> requestPhotosPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    } else {
      // Android 13+ uses granular permissions
      final status = await Permission.photos.request();
      return status.isGranted;
    }
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if photos permission is granted
  Future<bool> hasPhotosPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return await Permission.photos.isGranted;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Whether denied permission should route the user to app settings.
  ///
  /// iOS returns `denied` for states that require Settings after the first prompt.
  Future<bool> shouldOpenSettingsFor(Permission permission) async {
    final status = await permission.status;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return true;
    }
    if (Platform.isIOS && status.isDenied) {
      return true;
    }
    return false;
  }

  /// Open app settings for the user to grant permissions
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show permission denied dialog with option to open settings
  Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String purpose,
  }) async {
    if (PlatformUtils.isIOS) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('$permissionName Access Needed'),
          content: Text(
            'To $purpose, please allow $permissionName access in Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openSettings();
              },
            ),
          ],
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$permissionName Access Needed'),
          content: Text(
            'To $purpose, please allow $permissionName access in Settings.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openSettings();
              },
            ),
          ],
        ),
      );
    }
  }
}
