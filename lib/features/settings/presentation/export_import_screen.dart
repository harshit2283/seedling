import 'package:flutter/material.dart';

import '../../../core/platform/adaptive_icons.dart';
import 'widgets/data_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/settings_tiles.dart';

/// Every way to take memories out of Seedling, or bring them in.
class ExportImportScreen extends StatelessWidget {
  const ExportImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSubScreen(
      title: 'Export & import',
      children: [
        SettingsNote(deviceBackupNoteSubtitle, icon: AdaptiveIcons.info),
        const DataSection(),
      ],
    );
  }
}
