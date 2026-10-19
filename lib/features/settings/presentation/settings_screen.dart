import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/palette.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import 'widgets/about_section.dart';
import 'widgets/memories_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/prompts_section.dart';
import 'widgets/your_tree_section.dart';
import '../../../app/theme/bar_surfaces.dart';

/// Settings, in five short groups: Your tree, Gentle nudges, Privacy & sync,
/// Your memories, About. Anything with more than a couple of options (sync,
/// export & import) lives on its own screen one tap away.
///
/// Each section is a self-contained widget that only rebuilds when its own
/// providers change.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _sections = <Widget>[
    YourTreeSection(),
    PromptsSection(),
    PrivacySection(),
    MemoriesSection(),
    AboutSection(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: context.groupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: context.barBackground(
            under: context.groupedBackground,
          ),
          border: null,
          middle: const Text('Settings'),
          leading: CupertinoNavigationBarBackButton(
            color: context.palette.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              children: const [
                SizedBox(height: 8),
                ..._sections,
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: _sections,
      ),
    );
  }
}
