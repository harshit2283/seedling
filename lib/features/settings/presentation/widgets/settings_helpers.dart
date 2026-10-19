import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/palette.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/services/storage/storage_usage_service.dart';
import '../../../../core/widgets/feedback/seedling_toast.dart';
import 'storage_breakdown_donut.dart';

/// Show a gentle, non-blocking success message (toast on iOS, snackbar on
/// Android) with a light tap. Successes never need a modal "OK".
void showSettingsSuccess(BuildContext context, String message) {
  HapticFeedback.lightImpact();
  showSeedlingMessage(context, message);
}

/// Show an error message: a Cupertino alert on iOS (so it isn't missed),
/// an error snackbar on Android. A medium tap, not a jolt.
void showSettingsError(BuildContext context, String message) {
  final safeMessage = sanitizeUserMessage(message);
  HapticFeedback.mediumImpact();
  if (PlatformUtils.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("That didn't work"),
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
    showSeedlingMessage(context, safeMessage, isError: true);
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
      lower.contains('type \'') && lower.contains('is not a subtype of type')) {
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

  showSettingsError(context, 'Device authentication was not successful');
  return false;
}

/// Storage breakdown row used in the storage details dialog.
Widget buildStorageRow(String label, String value, {bool isBold = false}) {
  return Builder(
    builder: (context) => Row(
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
            color: context.palette.primary,
          ),
        ),
      ],
    ),
  );
}

/// Show storage breakdown dialog.
void showStorageDetails(BuildContext context, StorageUsage storage) {
  HapticFeedback.selectionClick();
  final body = Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StorageBreakdownDonut(usage: storage),
            const SizedBox(width: 16),
            Flexible(child: StorageBreakdownLegend(usage: storage)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Total: ${storage.totalFormatted}',
          style: TextStyle(
            color: context.palette.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  if (PlatformUtils.isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Storage'),
        content: body,
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
        title: const Text('Storage'),
        content: body,
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
