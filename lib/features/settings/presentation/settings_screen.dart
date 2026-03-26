import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import 'widgets/your_tree_section.dart';
import 'widgets/data_section.dart';
import 'widgets/prompts_section.dart';
import 'widgets/insights_section.dart';
import 'widgets/capsules_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/about_section.dart';
import 'widgets/memories_section.dart';
import 'widgets/experimental_section.dart';
import 'widgets/danger_zone_section.dart';

/// Settings screen with export, storage, and privacy info.
///
/// Each section is a self-contained ConsumerWidget (or ConsumerStatefulWidget)
/// that only rebuilds when its own providers change.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(context);
    }
    return _buildAndroidLayout(context);
  }

  Widget _buildIOSLayout(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground.withValues(
          alpha: 0.9,
        ),
        border: null,
        middle: const Text('Settings'),
        leading: CupertinoNavigationBarBackButton(
          color: SeedlingColors.forestGreen,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          children: const [
            SizedBox(height: 16),
            YourTreeSection(),
            DataSection(),
            PromptsSection(),
            InsightsSection(),
            CapsulesSection(),
            PrivacySection(),
            AboutSection(),
            MemoriesSection(),
            ExperimentalSection(),
            DangerZoneSection(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: const [
          SizedBox(height: 16),
          YourTreeSection(),
          SizedBox(height: 24),
          DataSection(),
          SizedBox(height: 24),
          PromptsSection(),
          SizedBox(height: 24),
          InsightsSection(),
          SizedBox(height: 24),
          PrivacySection(),
          SizedBox(height: 24),
          MemoriesSection(),
          SizedBox(height: 24),
          AboutSection(),
          SizedBox(height: 24),
          DangerZoneSection(),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
