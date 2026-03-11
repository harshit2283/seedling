import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/season.dart';
import '../platform/platform_utils.dart';
import '../services/ai/models/memory_theme.dart';
import '../../data/models/ritual.dart';

/// Shared icon mappings used to avoid emoji-heavy UI.
class SeedlingIconography {
  SeedlingIconography._();

  static IconData themeIcon(MemoryTheme theme) {
    switch (theme) {
      case MemoryTheme.family:
        return PlatformUtils.isIOS ? CupertinoIcons.home : Icons.home_outlined;
      case MemoryTheme.friends:
        return PlatformUtils.isIOS
            ? CupertinoIcons.person_2
            : Icons.groups_2_outlined;
      case MemoryTheme.work:
        return PlatformUtils.isIOS
            ? CupertinoIcons.briefcase
            : Icons.work_outline;
      case MemoryTheme.nature:
        return PlatformUtils.isIOS
            ? CupertinoIcons.leaf_arrow_circlepath
            : Icons.eco_outlined;
      case MemoryTheme.gratitude:
        return PlatformUtils.isIOS
            ? CupertinoIcons.heart
            : Icons.favorite_border;
      case MemoryTheme.reflection:
        return PlatformUtils.isIOS
            ? CupertinoIcons.moon_stars
            : Icons.nights_stay_outlined;
      case MemoryTheme.travel:
        return PlatformUtils.isIOS
            ? CupertinoIcons.paperplane
            : Icons.explore_outlined;
      case MemoryTheme.creativity:
        return PlatformUtils.isIOS
            ? CupertinoIcons.paintbrush
            : Icons.palette_outlined;
      case MemoryTheme.health:
        return PlatformUtils.isIOS
            ? CupertinoIcons.heart_circle
            : Icons.favorite_outline;
      case MemoryTheme.food:
        return PlatformUtils.isIOS
            ? CupertinoIcons.bag
            : Icons.restaurant_outlined;
      case MemoryTheme.moments:
        return PlatformUtils.isIOS
            ? CupertinoIcons.sparkles
            : Icons.auto_awesome_outlined;
    }
  }

  static IconData ritualStatusIcon(RitualStatus status) {
    switch (status) {
      case RitualStatus.active:
        return PlatformUtils.isIOS
            ? CupertinoIcons.play_circle
            : Icons.play_circle_outline;
      case RitualStatus.paused:
        return PlatformUtils.isIOS
            ? CupertinoIcons.pause_circle
            : Icons.pause_circle_outline;
      case RitualStatus.archived:
        return PlatformUtils.isIOS
            ? CupertinoIcons.archivebox
            : Icons.archive_outlined;
    }
  }

  static IconData seasonIcon(Season season) {
    switch (season) {
      case Season.spring:
        return PlatformUtils.isIOS
            ? CupertinoIcons.leaf_arrow_circlepath
            : Icons.spa_outlined;
      case Season.summer:
        return PlatformUtils.isIOS
            ? CupertinoIcons.sun_max
            : Icons.light_mode_outlined;
      case Season.autumn:
        return PlatformUtils.isIOS ? CupertinoIcons.wind : Icons.park_outlined;
      case Season.winter:
        return PlatformUtils.isIOS ? CupertinoIcons.snow : Icons.ac_unit;
    }
  }

  static IconData get tree =>
      PlatformUtils.isIOS ? CupertinoIcons.tree : Icons.park_outlined;
}
