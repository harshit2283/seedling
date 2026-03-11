import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'platform_utils.dart';

/// Provides platform-adaptive icons
/// Returns Cupertino icons on iOS, Material icons on Android
class AdaptiveIcons {
  AdaptiveIcons._();

  // Navigation
  static IconData get back =>
      PlatformUtils.isIOS ? CupertinoIcons.back : Icons.arrow_back;

  static IconData get settings =>
      PlatformUtils.isIOS ? CupertinoIcons.settings : Icons.settings_outlined;

  static IconData get menu =>
      PlatformUtils.isIOS ? CupertinoIcons.line_horizontal_3 : Icons.menu;

  static IconData get calendar => PlatformUtils.isIOS
      ? CupertinoIcons.calendar
      : Icons.calendar_today_outlined;

  static IconData get chevronRight =>
      PlatformUtils.isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right;

  // Entry types
  static IconData get quote =>
      PlatformUtils.isIOS ? CupertinoIcons.quote_bubble : Icons.format_quote;

  static IconData get sparkles => PlatformUtils.isIOS
      ? CupertinoIcons.sparkles
      : Icons.auto_awesome_outlined;

  static IconData get wind =>
      PlatformUtils.isIOS ? CupertinoIcons.wind : Icons.air;

  static IconData get photo =>
      PlatformUtils.isIOS ? CupertinoIcons.photo : Icons.photo_outlined;

  static IconData get mic =>
      PlatformUtils.isIOS ? CupertinoIcons.mic : Icons.mic_outlined;

  static IconData get category =>
      PlatformUtils.isIOS ? CupertinoIcons.cube : Icons.category_outlined;

  // Common
  static IconData get add =>
      PlatformUtils.isIOS ? CupertinoIcons.add : Icons.add;

  static IconData get leaf => PlatformUtils.isIOS
      ? CupertinoIcons.leaf_arrow_circlepath
      : Icons.spa_outlined;

  static IconData get tree =>
      PlatformUtils.isIOS ? CupertinoIcons.tree : Icons.park_outlined;

  static IconData get list => PlatformUtils.isIOS
      ? CupertinoIcons.list_number
      : Icons.format_list_numbered;

  static IconData get clock =>
      PlatformUtils.isIOS ? CupertinoIcons.clock : Icons.schedule_outlined;

  static IconData get cloud => PlatformUtils.isIOS
      ? CupertinoIcons.cloud_upload
      : Icons.cloud_upload_outlined;

  static IconData get download => PlatformUtils.isIOS
      ? CupertinoIcons.arrow_down_circle
      : Icons.download_outlined;

  static IconData get shield =>
      PlatformUtils.isIOS ? CupertinoIcons.shield : Icons.shield_outlined;

  static IconData get info =>
      PlatformUtils.isIOS ? CupertinoIcons.info : Icons.info_outline;

  static IconData get smartphone => PlatformUtils.isIOS
      ? CupertinoIcons.device_phone_portrait
      : Icons.smartphone;

  // Note: CupertinoIcons doesn't have a direct "cloud off" icon,
  // using a close alternative
  static IconData get cloudOff =>
      PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.cloud_off;

  static IconData get analytics => PlatformUtils.isIOS
      ? CupertinoIcons.graph_circle
      : Icons.analytics_outlined;

  static IconData get lock =>
      PlatformUtils.isIOS ? CupertinoIcons.lock : Icons.lock_outline;

  static IconData get error => PlatformUtils.isIOS
      ? CupertinoIcons.exclamationmark_circle
      : Icons.error_outline;

  static IconData get trash =>
      PlatformUtils.isIOS ? CupertinoIcons.trash : Icons.delete_outline;

  static IconData get restore =>
      PlatformUtils.isIOS ? CupertinoIcons.arrow_uturn_left : Icons.restore;

  static IconData get deleteForever =>
      PlatformUtils.isIOS ? CupertinoIcons.trash_slash : Icons.delete_forever;
}
