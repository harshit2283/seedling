import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/storage/storage_usage_service.dart';

/// Shared icon box used across all settings sections (iOS).
Widget buildSettingsIconBox(
  IconData icon,
  Color color, {
  bool isLight = false,
  bool isDanger = false,
}) {
  Color bgColor;
  if (isDanger) {
    bgColor = SeedlingColors.error.withValues(alpha: 0.15);
  } else if (isLight) {
    bgColor = Theme.of(context).dividerColor;
  } else {
    bgColor = SeedlingColors.paleGreen.withValues(alpha: 0.5);
  }

  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: color, size: 18),
  );
}

/// Material section wrapper with title header and rounded card.
Widget buildMaterialSection(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: SeedlingColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, indent: 56),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Material info tile (non-interactive).
Widget buildMaterialInfoTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SeedlingColors.paleGreen.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: SeedlingColors.forestGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Material switch tile.
Widget buildMaterialSwitchTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SeedlingColors.paleGreen.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: SeedlingColors.forestGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: SeedlingColors.forestGreen,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// Material action tile with chevron and optional loading indicator.
Widget buildMaterialActionTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool enabled = true,
  bool isDanger = false,
  bool isLoading = false,
}) {
  final iconColor = isDanger
      ? SeedlingColors.error
      : SeedlingColors.textSecondary;
  final bgColor = isDanger
      ? SeedlingColors.error.withValues(alpha: 0.15)
      : Theme.of(context).dividerColor;

  return Opacity(
    opacity: enabled && !isLoading ? 1.0 : 0.5,
    child: InkWell(
      onTap: enabled && !isLoading ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SeedlingColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (enabled)
              Icon(
                AdaptiveIcons.chevronRight,
                color: SeedlingColors.textMuted,
                size: 20,
              ),
          ],
        ),
      ),
    ),
  );
}

/// Show a success message (iOS dialog / Android snackbar).
void showSettingsSuccess(BuildContext context, String message) {
  HapticFeedback.lightImpact();
  if (PlatformUtils.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Done'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SeedlingColors.forestGreen,
      ),
    );
  }
}

/// Show an error message (iOS dialog / Android snackbar).
void showSettingsError(BuildContext context, String message) {
  final safeMessage = sanitizeUserMessage(message);
  HapticFeedback.heavyImpact();
  if (PlatformUtils.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Action Failed'),
        content: Text(safeMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(safeMessage),
        backgroundColor: SeedlingColors.error,
      ),
    );
  }
}

/// Sanitize error messages for user display.
String sanitizeUserMessage(
  String message, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return fallback;

  final firstLine = trimmed.split('\n').first.trim();
  if (firstLine.length > 180) return fallback;

  final withoutPrefix = firstLine.replaceFirst(
    RegExp(
      r'^(Exception|FormatException|PlatformException|StateError|ArgumentError)\s*:?\s*',
    ),
    '',
  );
  if (withoutPrefix.isEmpty) return fallback;

  final lower = withoutPrefix.toLowerCase();
  if (lower.contains('stack trace') ||
      lower.contains('type \'') &&
          lower.contains('is not a subtype of type')) {
    return fallback;
  }
  if (withoutPrefix.contains('/') || withoutPrefix.contains(r'\')) {
    return fallback;
  }

  return withoutPrefix;
}

/// Require biometric/passcode auth when app lock is enabled.
Future<bool> authorizeSensitiveAction(
  WidgetRef ref,
  BuildContext context,
  String reason,
) async {
  if (!ref.read(appLockEnabledProvider)) {
    return true;
  }

  final lockService = ref.read(appLockServiceProvider);
  final didAuth = await lockService.authenticate(reason: reason);
  if (!context.mounted) {
    return false;
  }
  if (didAuth) {
    return true;
  }

  showSettingsError(context, 'Device authentication was cancelled');
  return false;
}

/// Storage breakdown row used in the storage details dialog.
Widget buildStorageRow(String label, String value, {bool isBold = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: SeedlingColors.forestGreen,
        ),
      ),
    ],
  );
}

/// Show storage breakdown dialog.
void showStorageDetails(BuildContext context, StorageUsage storage) {
  HapticFeedback.selectionClick();
  if (PlatformUtils.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Storage Breakdown'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              buildStorageRow('Database', storage.databaseFormatted),
              const SizedBox(height: 8),
              buildStorageRow('Photos', storage.photosFormatted),
              const SizedBox(height: 8),
              buildStorageRow('Voice Memos', storage.voicesFormatted),
              const SizedBox(height: 8),
              buildStorageRow('Objects', storage.objectsFormatted),
              const Divider(height: 24),
              buildStorageRow('Total', storage.totalFormatted, isBold: true),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildStorageRow('Database', storage.databaseFormatted),
            const SizedBox(height: 8),
            buildStorageRow('Photos', storage.photosFormatted),
            const SizedBox(height: 8),
            buildStorageRow('Voice Memos', storage.voicesFormatted),
            const SizedBox(height: 8),
            buildStorageRow('Objects', storage.objectsFormatted),
            const Divider(height: 24),
            buildStorageRow('Total', storage.totalFormatted, isBold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// Compute the origin rect for the iOS share sheet.
Rect? shareSheetOriginRect(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.hasSize ||
      !renderObject.attached) {
    return null;
  }

  final size = renderObject.size;
  if (size.width <= 0 || size.height <= 0) return null;

  final origin = renderObject.localToGlobal(Offset.zero);
  if (!origin.dx.isFinite || !origin.dy.isFinite) return null;

  final center = Offset(
    origin.dx + (size.width / 2),
    origin.dy + (size.height / 2),
  );
  if (!center.dx.isFinite || !center.dy.isFinite) return null;

  return Rect.fromLTWH(center.dx, center.dy, 1, 1);
}
