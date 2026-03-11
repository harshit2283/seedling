import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';
import '../../../app/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/export/export_service.dart';
import '../../../core/services/notifications/gentle_reminder_service.dart';
import '../../../core/services/providers.dart';
import 'widgets/sync_status_tile.dart';
import '../../../core/services/storage/storage_usage_service.dart';
import '../../../core/services/ai/models/ritual_candidate.dart';
import '../../../data/models/entry.dart';

enum _ImportMode { merge, replace }

const _appVersion = '1.0.0';

/// Settings screen with export, storage, and privacy info
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isClearingData = false;
  bool _isRecountingTrees = false;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return _buildIOSLayout(context);
    }
    return _buildAndroidLayout(context);
  }

  Widget _buildIOSLayout(BuildContext context) {
    final entryCount = ref.watch(entryCountProvider);
    final tree = ref.watch(currentTreeProvider);
    final storageAsync = ref.watch(storageUsageProvider);
    final homeFeedScope = ref.watch(homeFeedScopeProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final widgetMemoryPreviewsEnabled = ref.watch(
      widgetMemoryPreviewsEnabledProvider,
    );
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final syncPassphraseConfiguredAsync = ref.watch(
      syncPassphraseConfiguredProvider,
    );
    final isSyncPassphraseConfigured =
        syncPassphraseConfiguredAsync.asData?.value ?? false;

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
          children: [
            const SizedBox(height: 16),
            // Your Tree section
            CupertinoListSection.insetGrouped(
              header: const Text('Your tree'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.tree,
                    SeedlingColors.forestGreen,
                  ),
                  title: Text(tree?.stateName ?? 'Seed'),
                  subtitle: Text(
                    tree?.stateDescription ?? 'Plant your first memory',
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.list,
                    SeedlingColors.forestGreen,
                  ),
                  title: Text('$entryCount memories'),
                  subtitle: const Text('This year'),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.clock,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Show past years on home'),
                  subtitle: Text(
                    homeFeedScope == HomeFeedScope.allYears
                        ? 'All years'
                        : 'Current year only',
                  ),
                  trailing: CupertinoSwitch(
                    value: homeFeedScope == HomeFeedScope.allYears,
                    activeTrackColor: SeedlingColors.forestGreen,
                    onChanged: (value) {
                      ref
                          .read(homeFeedScopeProvider.notifier)
                          .setScope(
                            value
                                ? HomeFeedScope.allYears
                                : HomeFeedScope.currentYear,
                          );
                    },
                  ),
                ),
              ],
            ),
            // Data section
            CupertinoListSection.insetGrouped(
              header: const Text('Your data'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.download,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Export as JSON'),
                  subtitle: const Text('Entries without media'),
                  trailing: _isExporting
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isExporting ? null : _exportJson,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.archivebox,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Export as ZIP'),
                  subtitle: const Text('Entries with all media'),
                  trailing: _isExporting
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isExporting ? null : _exportZip,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.lock,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Encrypted Backup'),
                  subtitle: const Text('Password-protected .seedling file'),
                  trailing: _isExporting
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isExporting ? null : _exportEncryptedBackup,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.download,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Import Encrypted Backup'),
                  subtitle: const Text('Restore from .seedling file'),
                  trailing: _isExporting
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isExporting ? null : _importEncryptedBackup,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.download,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Import Archive (ZIP)'),
                  subtitle: const Text('Restore from .zip export'),
                  trailing: _isExporting
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isExporting ? null : _importZipArchive,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.refresh,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Rebuild Tree Counts'),
                  subtitle: const Text('Repair yearly growth totals'),
                  trailing: _isRecountingTrees
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isRecountingTrees ? null : _recountTrees,
                ),
                _buildStorageTileIOS(storageAsync),
              ],
            ),
            // Prompts section
            CupertinoListSection.insetGrouped(
              header: const Text('Prompts'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.sparkles,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Gentle Prompts'),
                  subtitle: const Text(
                    'Thoughtful suggestions on the home screen',
                  ),
                  trailing: CupertinoSwitch(
                    value: ref.watch(promptsEnabledProvider),
                    activeTrackColor: SeedlingColors.forestGreen,
                    onChanged: (value) {
                      ref.read(promptSelectorProvider).setEnabled(value);
                      // Force rebuild
                      setState(() {});
                    },
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.bell,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Gentle Reminder'),
                  subtitle: const Text(
                    'Quiet reminder when no memories are added',
                  ),
                  trailing: CupertinoSwitch(
                    value: reminderSettings.enabled,
                    activeTrackColor: SeedlingColors.forestGreen,
                    onChanged: (value) {
                      ref
                          .read(reminderSettingsProvider.notifier)
                          .setEnabled(value);
                    },
                  ),
                ),
                if (reminderSettings.enabled)
                  CupertinoListTile(
                    leading: _buildIconBox(
                      CupertinoIcons.calendar,
                      SeedlingColors.forestGreen,
                    ),
                    title: const Text('Reminder cadence'),
                    subtitle: Text(reminderSettings.cadence.label),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _pickReminderCadence,
                  ),
                if (reminderSettings.enabled)
                  CupertinoListTile(
                    leading: _buildIconBox(
                      CupertinoIcons.time,
                      SeedlingColors.forestGreen,
                    ),
                    title: const Text('Reminder time'),
                    subtitle: Text(
                      _formatTime(
                        reminderSettings.hour,
                        reminderSettings.minute,
                      ),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _pickReminderTime,
                  ),
              ],
            ),
            // Insights section (Phase 4)
            CupertinoListSection.insetGrouped(
              header: const Text('Insights'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.chart_pie,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Theme Insights'),
                  subtitle: const Text('See patterns in your memories'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push(AppRoutes.themeInsights),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.arrow_2_circlepath,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Ritual Patterns'),
                  subtitle: const Text('View recurring memory patterns'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showRitualPatterns,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.repeat,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Manage Rituals'),
                  subtitle: const Text(
                    'View and manage your confirmed rituals',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push(AppRoutes.rituals),
                ),
              ],
            ),
            // Memory Capsules section (Phase 4.5)
            CupertinoListSection.insetGrouped(
              header: const Text('Time capsules'),
              children: [
                CupertinoListTile(
                  leading: _buildCapsuleIcon(),
                  title: const Text('Memory Capsules'),
                  subtitle: Text(_getCapsuleCountText()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push(AppRoutes.capsules),
                ),
              ],
            ),
            // Privacy section (inline info, no dialog)
            CupertinoListSection.insetGrouped(
              header: const Text('Privacy'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.smartphone,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('On your device'),
                  subtitle: const Text(
                    'Stored locally by default. Sync, widgets, export, and sharing are optional.',
                  ),
                ),
                const CupertinoListTile(title: SyncStatusTile()),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.square_grid_2x2,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Widget previews'),
                  subtitle: Text(
                    widgetMemoryPreviewsEnabled && !appLockEnabled
                        ? 'Memory text can appear in widgets'
                        : 'Aggregate-only widgets keep memory text hidden',
                  ),
                  trailing: CupertinoSwitch(
                    value: widgetMemoryPreviewsEnabled,
                    activeTrackColor: SeedlingColors.forestGreen,
                    onChanged: _toggleWidgetMemoryPreviews,
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.lock,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Sync passphrase'),
                  subtitle: Text(
                    isSyncPassphraseConfigured
                        ? 'Set (tap to update)'
                        : 'Required for encrypted cloud sync',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _configureSyncPassphrase,
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.lock,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('App Lock'),
                  subtitle: Text(
                    appLockEnabled ? 'Enabled' : 'Use device auth to unlock',
                  ),
                  trailing: CupertinoSwitch(
                    value: appLockEnabled,
                    activeTrackColor: SeedlingColors.forestGreen,
                    onChanged: _toggleAppLock,
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.lock,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('No tracking'),
                  subtitle: const Text('No analytics or data collection'),
                ),
              ],
            ),
            // About section
            CupertinoListSection.insetGrouped(
              header: const Text('About'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.info,
                    SeedlingColors.textSecondary,
                    isLight: true,
                  ),
                  title: const Text('About Seedling'),
                  additionalInfo: const Text('v$_appVersion'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
            // Year in Review section
            CupertinoListSection.insetGrouped(
              header: const Text('Memories'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.tree,
                    SeedlingColors.forestGreen,
                  ),
                  title: const Text('Year in Review'),
                  subtitle: Text('${DateTime.now().year}'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push('/review/${DateTime.now().year}'),
                ),
              ],
            ),
            // Experimental section
            CupertinoListSection.insetGrouped(
              header: const Text('Experimental'),
              footer: const Text(
                'These features are in testing and may change.',
              ),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.waveform,
                    SeedlingColors.accentVoice,
                  ),
                  title: const Text('Mood Arc'),
                  subtitle: const Text(
                    'Visualize sentiment across your entries',
                  ),
                  trailing: CupertinoSwitch(
                    value: ref.watch(moodVisualizationEnabledProvider),
                    activeTrackColor: SeedlingColors.accentVoice,
                    onChanged: (v) => ref
                        .read(moodVisualizationEnabledProvider.notifier)
                        .set(v),
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.square_grid_2x2,
                    SeedlingColors.accentPhoto,
                  ),
                  title: const Text('Memory Collage'),
                  subtitle: const Text('Grid view for photo memories'),
                  trailing: CupertinoSwitch(
                    value: ref.watch(collageViewEnabledProvider),
                    activeTrackColor: SeedlingColors.accentPhoto,
                    onChanged: (v) =>
                        ref.read(collageViewEnabledProvider.notifier).set(v),
                  ),
                ),
              ],
            ),
            // Danger Zone section
            CupertinoListSection.insetGrouped(
              header: const Text('Danger zone'),
              children: [
                CupertinoListTile(
                  leading: _buildIconBox(
                    AdaptiveIcons.trash,
                    SeedlingColors.error,
                    isDanger: true,
                  ),
                  title: const Text('Recently Deleted'),
                  subtitle: Text(_getDeletedCountText()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push(AppRoutes.deletedEntries),
                ),
                CupertinoListTile(
                  leading: _buildIconBox(
                    CupertinoIcons.trash_fill,
                    SeedlingColors.error,
                    isDanger: true,
                  ),
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Delete everything permanently'),
                  trailing: _isClearingData
                      ? const CupertinoActivityIndicator()
                      : const CupertinoListTileChevron(),
                  onTap: _isClearingData
                      ? null
                      : () => _confirmClearAllData(context),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(
    IconData icon,
    Color color, {
    bool isLight = false,
    bool isDanger = false,
  }) {
    Color bgColor;
    if (isDanger) {
      bgColor = SeedlingColors.error.withValues(alpha: 0.15);
    } else if (isLight) {
      bgColor = SeedlingColors.softCream;
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

  Widget _buildStorageTileIOS(AsyncValue<StorageUsage> storageAsync) {
    return storageAsync.when(
      data: (storage) => CupertinoListTile(
        leading: _buildIconBox(
          CupertinoIcons.chart_pie,
          SeedlingColors.forestGreen,
        ),
        title: const Text('Storage Used'),
        additionalInfo: Text(storage.totalFormatted),
        trailing: const CupertinoListTileChevron(),
        onTap: () => _showStorageDetails(context, storage),
      ),
      loading: () => CupertinoListTile(
        leading: _buildIconBox(
          CupertinoIcons.chart_pie,
          SeedlingColors.forestGreen,
        ),
        title: const Text('Storage Used'),
        trailing: const CupertinoActivityIndicator(),
      ),
      error: (error, stackTrace) => CupertinoListTile(
        leading: _buildIconBox(
          CupertinoIcons.chart_pie,
          SeedlingColors.textMuted,
          isLight: true,
        ),
        title: const Text('Storage Used'),
        additionalInfo: const Text('Error'),
      ),
    );
  }

  Widget _buildAndroidLayout(BuildContext context) {
    final entryCount = ref.watch(entryCountProvider);
    final tree = ref.watch(currentTreeProvider);
    final storageAsync = ref.watch(storageUsageProvider);
    final homeFeedScope = ref.watch(homeFeedScopeProvider);
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final widgetMemoryPreviewsEnabled = ref.watch(
      widgetMemoryPreviewsEnabledProvider,
    );
    final reminderSettings = ref.watch(reminderSettingsProvider);
    final syncPassphraseConfiguredAsync = ref.watch(
      syncPassphraseConfiguredProvider,
    );
    final isSyncPassphraseConfigured =
        syncPassphraseConfiguredAsync.asData?.value ?? false;

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
        children: [
          const SizedBox(height: 16),
          // Stats section
          _buildSection(
            context,
            title: 'Your Tree',
            children: [
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.tree,
                title: tree?.stateName ?? 'Seed',
                subtitle: tree?.stateDescription ?? 'Plant your first memory',
              ),
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.list,
                title: '$entryCount memories',
                subtitle: 'This year',
              ),
              _buildSwitchTile(
                context,
                icon: AdaptiveIcons.clock,
                title: 'Show past years on home',
                subtitle: homeFeedScope == HomeFeedScope.allYears
                    ? 'All years'
                    : 'Current year only',
                value: homeFeedScope == HomeFeedScope.allYears,
                onChanged: (value) {
                  ref
                      .read(homeFeedScopeProvider.notifier)
                      .setScope(
                        value
                            ? HomeFeedScope.allYears
                            : HomeFeedScope.currentYear,
                      );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Data section
          _buildSection(
            context,
            title: 'Data',
            children: [
              _buildActionTile(
                context,
                icon: AdaptiveIcons.download,
                title: 'Export as JSON',
                subtitle: 'Entries without media',
                onTap: _exportJson,
                isLoading: _isExporting,
              ),
              _buildActionTile(
                context,
                icon: Icons.archive_outlined,
                title: 'Export as ZIP',
                subtitle: 'Entries with all media',
                onTap: _exportZip,
                isLoading: _isExporting,
              ),
              _buildActionTile(
                context,
                icon: AdaptiveIcons.lock,
                title: 'Encrypted Backup',
                subtitle: 'Password-protected .seedling file',
                onTap: _exportEncryptedBackup,
                isLoading: _isExporting,
              ),
              _buildActionTile(
                context,
                icon: AdaptiveIcons.download,
                title: 'Import Encrypted Backup',
                subtitle: 'Restore from .seedling file',
                onTap: _importEncryptedBackup,
                isLoading: _isExporting,
              ),
              _buildActionTile(
                context,
                icon: AdaptiveIcons.download,
                title: 'Import Archive (ZIP)',
                subtitle: 'Restore from .zip export',
                onTap: _importZipArchive,
                isLoading: _isExporting,
              ),
              _buildActionTile(
                context,
                icon: Icons.refresh,
                title: 'Rebuild Tree Counts',
                subtitle: 'Repair yearly growth totals',
                onTap: _recountTrees,
                isLoading: _isRecountingTrees,
              ),
              _buildStorageTileMaterial(context, storageAsync),
            ],
          ),
          const SizedBox(height: 24),
          // Prompts section
          _buildSection(
            context,
            title: 'Prompts',
            children: [
              _buildSwitchTile(
                context,
                icon: Icons.auto_awesome,
                title: 'Gentle Prompts',
                subtitle: 'Thoughtful suggestions on the home screen',
                value: ref.watch(promptsEnabledProvider),
                onChanged: (value) {
                  ref.read(promptSelectorProvider).setEnabled(value);
                  setState(() {});
                },
              ),
              _buildSwitchTile(
                context,
                icon: Icons.notifications_outlined,
                title: 'Gentle Reminder',
                subtitle: 'Quiet reminder if no memories are added',
                value: reminderSettings.enabled,
                onChanged: (value) {
                  ref.read(reminderSettingsProvider.notifier).setEnabled(value);
                },
              ),
              if (reminderSettings.enabled)
                _buildActionTile(
                  context,
                  icon: Icons.calendar_today_outlined,
                  title: 'Reminder cadence',
                  subtitle: reminderSettings.cadence.label,
                  onTap: _pickReminderCadence,
                ),
              if (reminderSettings.enabled)
                _buildActionTile(
                  context,
                  icon: Icons.access_time,
                  title: 'Reminder time',
                  subtitle: _formatTime(
                    reminderSettings.hour,
                    reminderSettings.minute,
                  ),
                  onTap: _pickReminderTime,
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Insights section (Phase 4)
          _buildSection(
            context,
            title: 'Insights',
            children: [
              _buildActionTile(
                context,
                icon: Icons.pie_chart_outline,
                title: 'Theme Insights',
                subtitle: 'See patterns in your memories',
                onTap: () => context.push(AppRoutes.themeInsights),
              ),
              _buildActionTile(
                context,
                icon: Icons.autorenew,
                title: 'Ritual Patterns',
                subtitle: 'View recurring memory patterns',
                onTap: _showRitualPatterns,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Privacy section (inline info, no dialog)
          _buildSection(
            context,
            title: 'Privacy',
            children: [
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.smartphone,
                title: 'On your device',
                subtitle:
                    'Stored locally by default. Sync, widgets, export, and sharing are optional.',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SyncStatusTile(),
              ),
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.lock,
                title: 'Sync passphrase',
                subtitle: isSyncPassphraseConfigured
                    ? 'Set (tap to update)'
                    : 'Required for encrypted cloud sync',
              ),
              _buildActionTile(
                context,
                icon: AdaptiveIcons.lock,
                title: isSyncPassphraseConfigured
                    ? 'Update Sync Passphrase'
                    : 'Set Sync Passphrase',
                subtitle: 'Used for end-to-end encrypted sync payloads',
                onTap: _configureSyncPassphrase,
              ),
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.lock,
                title: 'App Lock',
                subtitle: appLockEnabled
                    ? 'Enabled'
                    : 'Use device auth to unlock',
              ),
              _buildSwitchTile(
                context,
                icon: AdaptiveIcons.lock,
                title: 'Enable App Lock',
                subtitle: 'Uses device biometrics/passcode',
                value: appLockEnabled,
                onChanged: _toggleAppLock,
              ),
              _buildSwitchTile(
                context,
                icon: Icons.widgets_outlined,
                title: 'Widget memory previews',
                subtitle: widgetMemoryPreviewsEnabled && !appLockEnabled
                    ? 'Memory text may appear in widgets'
                    : 'Widgets show aggregate-only details',
                value: widgetMemoryPreviewsEnabled,
                onChanged: _toggleWidgetMemoryPreviews,
              ),
              _buildInfoTile(
                context,
                icon: AdaptiveIcons.lock,
                title: 'No tracking',
                subtitle: 'No analytics or data collection',
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Year in Review section
          _buildSection(
            context,
            title: 'Memories',
            children: [
              _buildActionTile(
                context,
                icon: Icons.park_outlined,
                title: 'Year in Review',
                subtitle: '${DateTime.now().year}',
                onTap: () => context.push('/review/${DateTime.now().year}'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // About section
          _buildSection(
            context,
            title: 'About',
            children: [
              _buildActionTile(
                context,
                icon: AdaptiveIcons.info,
                title: 'About Seedling',
                subtitle: 'Version $_appVersion',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Danger Zone section
          _buildSection(
            context,
            title: 'Danger Zone',
            children: [
              _buildActionTile(
                context,
                icon: AdaptiveIcons.trash,
                title: 'Recently Deleted',
                subtitle: _getDeletedCountText(),
                onTap: () => context.push(AppRoutes.deletedEntries),
                isDanger: true,
              ),
              _buildActionTile(
                context,
                icon: Icons.delete_forever,
                title: 'Clear All Data',
                subtitle: 'Delete everything permanently',
                onTap: () => _confirmClearAllData(context),
                isDanger: true,
                isLoading: _isClearingData,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStorageTileMaterial(
    BuildContext context,
    AsyncValue<StorageUsage> storageAsync,
  ) {
    return storageAsync.when(
      data: (storage) => _buildActionTile(
        context,
        icon: Icons.pie_chart_outline,
        title: 'Storage Used',
        subtitle: storage.totalFormatted,
        onTap: () => _showStorageDetails(context, storage),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SeedlingColors.softCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.pie_chart_outline,
                color: SeedlingColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Calculating...'),
            const Spacer(),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => _buildActionTile(
        context,
        icon: Icons.pie_chart_outline,
        title: 'Storage Used',
        subtitle: 'Error calculating',
        enabled: false,
        onTap: () {},
      ),
    );
  }

  Widget _buildSection(
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
            color: SeedlingColors.warmWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SeedlingColors.softCream),
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

  Widget _buildInfoTile(
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

  Widget _buildSwitchTile(
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

  Widget _buildActionTile(
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
        : SeedlingColors.softCream;

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

  // ============== Export Functions ==============

  Future<void> _exportJson() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to export your memories',
    );
    if (!authorized) return;
    if (!mounted) return;
    final shareOrigin = _shareSheetOriginRect(context);
    setState(() => _isExporting = true);

    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.exportToJson(entries);

      if (result.success && result.filePath != null) {
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Memories Export',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        _showSuccessMessage(context, 'Export ready to share');
      } else {
        if (!mounted) return;
        _showErrorMessage(context, result.error ?? 'Export failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportZip() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to export your memories',
    );
    if (!authorized) return;
    if (!mounted) return;
    final shareOrigin = _shareSheetOriginRect(context);
    setState(() => _isExporting = true);

    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      final result = await exportService.exportToZip(
        entries,
        fileStorage.basePath,
      );

      if (result.success && result.filePath != null) {
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Backup',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        _showSuccessMessage(context, 'Backup ready to share');
      } else {
        if (!mounted) return;
        _showErrorMessage(context, result.error ?? 'Export failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _recountTrees() async {
    HapticFeedback.selectionClick();
    setState(() => _isRecountingTrees = true);

    try {
      await ref.read(databaseMaintenanceProvider.notifier).recountTrees();
      if (!mounted) return;
      _showSuccessMessage(context, 'Tree counts rebuilt successfully');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, 'Could not rebuild tree counts');
    } finally {
      if (mounted) {
        setState(() => _isRecountingTrees = false);
      }
    }
  }

  Future<void> _exportEncryptedBackup() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to create an encrypted backup',
    );
    if (!authorized) return;
    if (!mounted) return;
    final passphrase = await _promptForPassphrase(
      context,
      title: 'Create Encrypted Backup',
      message: 'Set a passphrase (minimum 8 characters).',
      confirm: true,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }
    if (!mounted) return;
    final shareOrigin = _shareSheetOriginRect(context);

    setState(() => _isExporting = true);
    try {
      final entries = ref.read(allEntriesProvider);
      final exportService = ref.read(exportServiceProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      final result = await exportService.exportEncryptedBackup(
        entries,
        fileStorage.basePath,
        passphrase: passphrase,
      );

      if (result.success && result.filePath != null) {
        await exportService.shareFile(
          result.filePath!,
          subject: 'Seedling Encrypted Backup',
          sharePositionOrigin: shareOrigin,
        );
        if (!mounted) return;
        _showSuccessMessage(context, 'Encrypted backup ready to share');
      } else {
        if (!mounted) return;
        _showErrorMessage(context, result.error ?? 'Encrypted backup failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importEncryptedBackup() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to import a backup',
    );
    if (!authorized) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['seedling'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }
    if (!mounted) return;

    final passphrase = await _promptForPassphrase(
      context,
      title: 'Unlock Backup',
      message: 'Enter the passphrase for this encrypted backup.',
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(exportServiceProvider);
      final loaded = await exportService.loadEncryptedBackup(
        path,
        passphrase: passphrase,
      );

      if (!mounted) return;
      final mode = await _promptImportMode(context, loaded.preview);
      if (mode == null) {
        return;
      }
      if (!mounted) return;

      if (mode == _ImportMode.replace) {
        final localCountBefore = ref.read(allEntriesProvider).length;
        final confirmed = await _confirmReplaceImport(
          context,
          localCount: localCountBefore,
        );
        if (!confirmed) return;
        final appLockService = ref.read(appLockServiceProvider);
        final didAuth = await appLockService.authenticate();
        if (!didAuth) {
          if (!mounted) return;
          _showErrorMessage(context, 'Device authentication was cancelled');
          return;
        }
      }

      final result = await _restoreLoadedBackup(loaded, mode: mode);
      if (!mounted) return;

      if (result.success) {
        await _showImportRecap(context, result);
      } else {
        _showErrorMessage(context, result.error ?? 'Import failed');
      }
    } on SecretBoxAuthenticationError {
      if (!mounted) return;
      _showErrorMessage(context, 'Invalid backup passphrase');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, 'Import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importZipArchive() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to import a backup',
    );
    if (!authorized) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }
    if (!mounted) return;

    setState(() => _isExporting = true);
    try {
      final exportService = ref.read(exportServiceProvider);
      final loaded = await exportService.loadZipArchive(path);

      if (!mounted) return;
      final mode = await _promptImportMode(context, loaded.preview);
      if (mode == null) {
        return;
      }
      if (!mounted) return;

      if (mode == _ImportMode.replace) {
        final localCountBefore = ref.read(allEntriesProvider).length;
        final confirmed = await _confirmReplaceImport(
          context,
          localCount: localCountBefore,
        );
        if (!confirmed) return;
        final appLockService = ref.read(appLockServiceProvider);
        final didAuth = await appLockService.authenticate();
        if (!didAuth) {
          if (!mounted) return;
          _showErrorMessage(context, 'Device authentication was cancelled');
          return;
        }
      }

      final result = await _restoreLoadedBackup(loaded, mode: mode);
      if (!mounted) return;

      if (result.success) {
        await _showImportRecap(context, result);
      } else {
        _showErrorMessage(context, result.error ?? 'Import failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, 'Archive import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Rect? _shareSheetOriginRect(BuildContext context) {
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

  String _formatTime(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $suffix';
  }

  Future<void> _pickReminderCadence() async {
    final current = ref.read(reminderSettingsProvider);
    final selected = await showModalBottomSheet<ReminderCadence>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: ReminderCadence.values.map((cadence) {
              return ListTile(
                title: Text(cadence.label),
                trailing: cadence == current.cadence
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(cadence),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await ref.read(reminderSettingsProvider.notifier).setCadence(selected);
    }
  }

  Future<void> _pickReminderTime() async {
    final current = ref.read(reminderSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .setTime(hour: picked.hour, minute: picked.minute);
  }

  Future<void> _showRitualPatterns() async {
    final candidates = ref.read(ritualCandidatesProvider);
    if (candidates.isEmpty) {
      _showSuccessMessage(context, 'No recurring patterns yet');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length.clamp(0, 12),
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              return ListTile(
                leading: const Icon(Icons.autorenew),
                title: Text(candidate.signature.replaceAll(':', ' • ')),
                subtitle: Text(
                  '${candidate.occurrences} times • '
                  '${candidate.spanDays} day span • '
                  'last ${candidate.daysSinceLastSeen}d ago',
                ),
                trailing: PlatformUtils.isIOS
                    ? CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _confirmRitual(candidate);
                        },
                        child: Text(
                          'Confirm',
                          style: TextStyle(
                            color: SeedlingColors.forestGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _confirmRitual(candidate);
                        },
                        child: Text(
                          'Confirm',
                          style: TextStyle(color: SeedlingColors.forestGreen),
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmRitual(RitualCandidate candidate) async {
    final nameController = TextEditingController(
      text: candidate.signature
          .replaceAll('-', ' ')
          .replaceAll(':', ' ')
          .trim(),
    );
    int cadenceDays = 7;
    int preferredHour = 9;

    final cadenceOptions = [
      (label: 'Daily', days: 1),
      (label: 'Every 3 days', days: 3),
      (label: 'Weekly', days: 7),
      (label: 'Biweekly', days: 14),
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: PlatformUtils.isIOS
                    ? CupertinoColors.systemBackground.darkColor.withValues(
                        alpha: 0.95,
                      )
                    : SeedlingColors.creamPaper,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: SeedlingColors.textMuted.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create ritual',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Name field
                      Text(
                        'Name',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      PlatformUtils.isIOS
                          ? CupertinoTextField(
                              controller: nameController,
                              placeholder: 'Ritual name',
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SeedlingColors.softCream,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            )
                          : TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                hintText: 'Ritual name',
                                filled: true,
                                fillColor: SeedlingColors.softCream,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                      const SizedBox(height: 20),
                      // Cadence picker
                      Text(
                        'Cadence',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: cadenceOptions.map((opt) {
                          final selected = cadenceDays == opt.days;
                          return ChoiceChip(
                            label: Text(opt.label),
                            selected: selected,
                            selectedColor: SeedlingColors.forestGreen
                                .withValues(alpha: 0.2),
                            onSelected: (_) {
                              setSheetState(() => cadenceDays = opt.days);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Preferred hour
                      Text(
                        'Reminder time',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SeedlingColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          if (PlatformUtils.isIOS) {
                            await showCupertinoModalPopup<void>(
                              context: context,
                              builder: (_) => Container(
                                height: 216,
                                color: CupertinoColors.systemBackground
                                    .resolveFrom(context),
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.time,
                                  initialDateTime: DateTime(
                                    2024,
                                    1,
                                    1,
                                    preferredHour,
                                  ),
                                  onDateTimeChanged: (dt) {
                                    setSheetState(
                                      () => preferredHour = dt.hour,
                                    );
                                  },
                                ),
                              ),
                            );
                          } else {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: preferredHour,
                                minute: 0,
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() => preferredHour = picked.hour);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: SeedlingColors.softCream,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PlatformUtils.isIOS
                                    ? CupertinoIcons.clock
                                    : Icons.access_time,
                                size: 18,
                                color: SeedlingColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${preferredHour.toString().padLeft(2, '0')}:00',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Create button
                      SizedBox(
                        width: double.infinity,
                        child: PlatformUtils.isIOS
                            ? CupertinoButton.filled(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                child: const Text('Create Ritual'),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SeedlingColors.forestGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Create Ritual'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim();
    nameController.dispose();

    await ref
        .read(ritualServiceProvider)
        .createFromCandidate(
          candidate,
          name: name,
          cadenceDays: cadenceDays,
          preferredHour: preferredHour,
        );

    HapticFeedback.mediumImpact();
    if (mounted) {
      _showSuccessMessage(context, 'Ritual created');
    }
  }

  Future<ImportResult> _restoreLoadedBackup(
    LoadedEncryptedBackup loaded, {
    required _ImportMode mode,
  }) async {
    final database = ref.read(databaseProvider);
    final fileStorage = ref.read(fileStorageServiceProvider);
    final existingEntries = mode == _ImportMode.merge
        ? database.getAllEntries()
        : <Entry>[];
    final seenFingerprints = existingEntries
        .map((entry) => _entryFingerprint(entry))
        .toSet();

    if (mode == _ImportMode.replace) {
      await fileStorage.clearAllMedia();
      await database.clearAllData();
      seenFingerprints.clear();
    }

    var importedEntries = 0;
    var importedMediaFiles = 0;
    var skippedDuplicates = 0;
    final warnings = [...loaded.warnings];

    for (final entryMap in loaded.entries) {
      final fingerprint = _mapFingerprint(entryMap);
      if (mode == _ImportMode.merge && seenFingerprints.contains(fingerprint)) {
        skippedDuplicates++;
        continue;
      }

      final restoredMediaPath = await _restoreMediaForEntry(
        entryMap: entryMap,
        mediaFiles: loaded.mediaFiles,
      );
      if (restoredMediaPath == null && entryMap['mediaPath'] != null) {
        warnings.add('missing_media');
      } else if (restoredMediaPath != null) {
        importedMediaFiles++;
      }

      final createdAt =
          DateTime.tryParse((entryMap['createdAt'] as String?) ?? '') ??
          DateTime.now();
      final type = _parseEntryType(entryMap['type'] as String?);
      final entry = Entry(
        createdAt: createdAt,
        typeIndex: type.index,
        text: entryMap['text'] as String?,
        mediaPath: restoredMediaPath,
        title: entryMap['title'] as String?,
        context: entryMap['context'] as String?,
        mood: entryMap['mood'] as String?,
        tags: entryMap['tags'] as String?,
        isReleased: (entryMap['isReleased'] as bool?) ?? false,
        detectedTheme: entryMap['detectedTheme'] as String?,
        sentimentScore: (entryMap['sentimentScore'] as num?)?.toDouble(),
        lastAnalyzedAt: DateTime.tryParse(
          (entryMap['lastAnalyzedAt'] as String?) ?? '',
        ),
        capsuleUnlockDate: DateTime.tryParse(
          (entryMap['capsuleUnlockDate'] as String?) ?? '',
        ),
      );

      await database.saveEntry(entry);
      seenFingerprints.add(fingerprint);
      importedEntries++;
    }

    await database.recountTrees();
    return ImportResult.success(
      importedEntries: importedEntries,
      importedMediaFiles: importedMediaFiles,
      skippedDuplicates: skippedDuplicates,
      warnings: warnings,
    );
  }

  Future<String?> _restoreMediaForEntry({
    required Map<String, dynamic> entryMap,
    required Map<String, List<int>> mediaFiles,
  }) async {
    final rawMediaPath = entryMap['mediaPath'] as String?;
    if (rawMediaPath == null || rawMediaPath.isEmpty) {
      return null;
    }
    final bytes = mediaFiles[rawMediaPath];
    if (bytes == null) {
      return null;
    }

    final fileStorage = ref.read(fileStorageServiceProvider);
    final type = _parseEntryType(entryMap['type'] as String?);
    final extension = _extensionFromArchivePath(rawMediaPath);

    String targetPath;
    switch (type) {
      case EntryType.photo:
        targetPath = await fileStorage.generatePhotoPath(extension: extension);
        break;
      case EntryType.object:
        targetPath = await fileStorage.generateObjectPhotoPath(
          extension: extension,
        );
        break;
      case EntryType.voice:
        targetPath = await fileStorage.generateVoicePath(extension: extension);
        break;
      default:
        targetPath = await fileStorage.generatePhotoPath(extension: extension);
        break;
    }

    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  EntryType _parseEntryType(String? rawType) {
    if (rawType == null) return EntryType.line;
    return EntryType.values.firstWhere(
      (type) => type.name == rawType,
      orElse: () => EntryType.line,
    );
  }

  String _extensionFromArchivePath(String path) {
    final fileName = path.split('/').last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return 'bin';
    }
    return fileName.substring(dot + 1);
  }

  Future<_ImportMode?> _promptImportMode(
    BuildContext context,
    EncryptedBackupPreview preview,
  ) async {
    final exportDate = preview.exportedAt == null
        ? 'Unknown'
        : DateFormat('MMM d, y • h:mm a').format(preview.exportedAt!);
    final integrityText = preview.integrityVerified
        ? 'Integrity verified'
        : 'Legacy backup (integrity signature unavailable)';
    final summary =
        '${preview.entryCount} memories\n'
        '${preview.mediaCount} media files\n'
        'Exported: $exportDate\n'
        '$integrityText';

    if (PlatformUtils.isIOS) {
      return showCupertinoDialog<_ImportMode>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Import Backup'),
          content: Text(summary),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(_ImportMode.merge),
              child: const Text('Merge (Keep current + add missing)'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(_ImportMode.replace),
              child: const Text('Replace (Erase current and restore)'),
            ),
          ],
        ),
      );
    }

    return showDialog<_ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.merge),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ImportMode.replace),
            style: TextButton.styleFrom(foregroundColor: SeedlingColors.error),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplaceImport(
    BuildContext context, {
    required int localCount,
  }) async {
    final contentText =
        'This will delete $localCount local memories and restore only this backup.';
    if (PlatformUtils.isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Replace all local data?'),
          content: Text(contentText),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all local data?'),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: SeedlingColors.error),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showImportRecap(
    BuildContext context,
    ImportResult result,
  ) async {
    final hasWarnings = result.warnings.isNotEmpty;
    final warningText = hasWarnings
        ? '\nWarnings: ${result.warnings.map(_formatWarning).join(', ')}'
        : '';
    final message =
        'Imported ${result.importedEntries} memories\n'
        'Restored ${result.importedMediaFiles} media files\n'
        'Skipped ${result.skippedDuplicates} duplicates$warningText';

    final hasCapsules = ref.read(capsulesProvider).isNotEmpty;

    if (PlatformUtils.isIOS) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Import Complete'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.memories);
              },
              child: const Text('Open Memories'),
            ),
            if (hasCapsules)
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.push(AppRoutes.capsules);
                },
                child: const Text('Open Capsules'),
              ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Complete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoutes.memories);
            },
            child: const Text('Open Memories'),
          ),
          if (hasCapsules)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.capsules);
              },
              child: const Text('Open Capsules'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _formatWarning(String warningCode) {
    switch (warningCode) {
      case 'integrity_not_verified':
        return 'legacy backup integrity not verified';
      case 'missing_media':
        return 'some media files were missing';
      default:
        return warningCode;
    }
  }

  String _entryFingerprint(Entry entry) {
    final createdAt = entry.createdAt.toIso8601String();
    final type = entry.type.name;
    final text = (entry.text ?? '').trim().toLowerCase();
    final title = (entry.title ?? '').trim().toLowerCase();
    final capsule = entry.capsuleUnlockDate?.toIso8601String() ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  String _mapFingerprint(Map<String, dynamic> map) {
    final createdAt = (map['createdAt'] as String?) ?? '';
    final type = (map['type'] as String?) ?? '';
    final text = ((map['text'] as String?) ?? '').trim().toLowerCase();
    final title = ((map['title'] as String?) ?? '').trim().toLowerCase();
    final capsule = (map['capsuleUnlockDate'] as String?) ?? '';
    return '$createdAt|$type|$text|$title|$capsule';
  }

  Future<String?> _promptForPassphrase(
    BuildContext context, {
    required String title,
    required String message,
    bool confirm = false,
  }) async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    if (PlatformUtils.isIOS) {
      return showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: passController,
                    placeholder: 'Passphrase',
                    obscureText: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (confirm) ...[
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: confirmController,
                      placeholder: 'Confirm passphrase',
                      obscureText: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final pass = passController.text.trim();
                  if (pass.length < 8) {
                    _showErrorMessage(
                      context,
                      'Passphrase must be at least 8 characters',
                    );
                    return;
                  }
                  if (confirm && pass != confirmController.text.trim()) {
                    _showErrorMessage(context, 'Passphrases do not match');
                    return;
                  }
                  Navigator.of(dialogContext).pop(pass);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (confirm) ...[
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passphrase',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pass = passController.text.trim();
              if (pass.length < 8) {
                _showErrorMessage(
                  context,
                  'Passphrase must be at least 8 characters',
                );
                return;
              }
              if (confirm && pass != confirmController.text.trim()) {
                _showErrorMessage(context, 'Passphrases do not match');
                return;
              }
              Navigator.of(dialogContext).pop(pass);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _configureSyncPassphrase() async {
    HapticFeedback.selectionClick();
    final authorized = await _authorizeSensitiveAction(
      'Authenticate to change your sync passphrase',
    );
    if (!authorized) return;
    if (!mounted) return;
    final passphrase = await _promptForPassphrase(
      context,
      title: 'Sync Passphrase',
      message: 'Set or update the passphrase used to encrypt sync payloads.',
      confirm: true,
    );
    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    try {
      await ref.read(syncCryptoServiceProvider).setPassphrase(passphrase);
      ref.invalidate(syncPassphraseConfiguredProvider);
      if (!mounted) return;
      _showSuccessMessage(context, 'Sync passphrase saved');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, e.toString());
    }
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      final lockService = ref.read(appLockServiceProvider);
      final canAuth = await lockService.canAuthenticate();
      if (!canAuth) {
        if (!mounted) return;
        _showErrorMessage(
          context,
          'Device authentication is not available on this device',
        );
        return;
      }
    } else {
      final authorized = await _authorizeSensitiveAction(
        'Authenticate to disable app lock',
      );
      if (!authorized) return;
    }

    try {
      if (enabled) {
        await ref
            .read(widgetMemoryPreviewsEnabledProvider.notifier)
            .setEnabled(false);
      }
      await ref.read(appLockEnabledProvider.notifier).setEnabled(enabled);
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(
        context,
        enabled
            ? 'Could not enable App Lock right now'
            : 'Could not disable App Lock right now',
      );
      return;
    }
    if (!mounted) return;
    _showSuccessMessage(
      context,
      enabled ? 'App lock enabled' : 'App lock disabled',
    );
  }

  Future<bool> _authorizeSensitiveAction(String reason) async {
    if (!ref.read(appLockEnabledProvider)) {
      return true;
    }

    final lockService = ref.read(appLockServiceProvider);
    final didAuth = await lockService.authenticate(reason: reason);
    if (!mounted) {
      return false;
    }
    if (didAuth) {
      return true;
    }

    _showErrorMessage(context, 'Device authentication was cancelled');
    return false;
  }

  Future<void> _toggleWidgetMemoryPreviews(bool enabled) async {
    if (enabled && ref.read(appLockEnabledProvider)) {
      _showErrorMessage(
        context,
        'Disable App Lock before showing memory previews in widgets',
      );
      return;
    }

    await ref
        .read(widgetMemoryPreviewsEnabledProvider.notifier)
        .setEnabled(enabled);
    if (!mounted) return;
    _showSuccessMessage(
      context,
      enabled
          ? 'Widget previews enabled'
          : 'Widget previews hidden for privacy',
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
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

  void _showErrorMessage(BuildContext context, String message) {
    final safeMessage = _sanitizeUserMessage(message);
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

  String _sanitizeUserMessage(
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

  // ============== Storage Details ==============

  void _showStorageDetails(BuildContext context, StorageUsage storage) {
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
                _buildStorageRow('Database', storage.databaseFormatted),
                const SizedBox(height: 8),
                _buildStorageRow('Photos', storage.photosFormatted),
                const SizedBox(height: 8),
                _buildStorageRow('Voice Memos', storage.voicesFormatted),
                const SizedBox(height: 8),
                _buildStorageRow('Objects', storage.objectsFormatted),
                const Divider(height: 24),
                _buildStorageRow('Total', storage.totalFormatted, isBold: true),
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
              _buildStorageRow('Database', storage.databaseFormatted),
              const SizedBox(height: 8),
              _buildStorageRow('Photos', storage.photosFormatted),
              const SizedBox(height: 8),
              _buildStorageRow('Voice Memos', storage.voicesFormatted),
              const SizedBox(height: 8),
              _buildStorageRow('Objects', storage.objectsFormatted),
              const Divider(height: 24),
              _buildStorageRow('Total', storage.totalFormatted, isBold: true),
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

  Widget _buildStorageRow(String label, String value, {bool isBold = false}) {
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

  // ============== Clear All Data ==============

  void _confirmClearAllData(BuildContext context) {
    HapticFeedback.heavyImpact();
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Clear All Data?'),
          content: const Text(
            'This will permanently delete ALL your memories, including photos and voice memos. This action cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmClearAllDataSecond(context);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear All Data?'),
          content: const Text(
            'This will permanently delete ALL your memories, including photos and voice memos. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _confirmClearAllDataSecond(context);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  void _confirmClearAllDataSecond(BuildContext context) {
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: const Text(
            'This is your last chance to cancel this destructive action.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _clearAllData();
              },
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: const Text('This is your last chance to cancel.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SeedlingColors.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                _clearAllData();
              },
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    if (_isClearingData) return;

    final didAuthorize = await _authorizeSensitiveAction(
      'Authenticate to clear all Seedling data',
    );
    if (!didAuthorize) return;

    setState(() => _isClearingData = true);

    try {
      final database = ref.read(databaseProvider);
      final fileStorage = ref.read(fileStorageServiceProvider);
      await fileStorage.clearAllMedia();
      await database.clearAllData();
      if (!mounted) return;
      _showSuccessMessage(context, 'All data was permanently deleted');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(context, 'Failed to clear data: $e');
    } finally {
      if (mounted) {
        setState(() => _isClearingData = false);
      }
    }
  }

  // ============== Helper Methods ==============

  String _getDeletedCountText() {
    final deletedEntries = ref.watch(deletedEntriesProvider);
    final count = deletedEntries.length;
    if (count == 0) return 'No deleted memories';
    if (count == 1) return '1 memory';
    return '$count memories';
  }

  String _getCapsuleCountText() {
    final capsules = ref.watch(capsulesProvider);
    final locked = capsules.where((c) => c.isLocked).length;
    final unlocked = capsules.where((c) => c.isUnlocked).length;
    if (capsules.isEmpty) return 'No capsules yet';
    if (locked == 0) return '$unlocked unlocked';
    if (unlocked == 0) return '$locked waiting to unlock';
    return '$locked locked, $unlocked unlocked';
  }

  Widget _buildCapsuleIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: SeedlingColors.themeGratitude.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          AdaptiveIcons.leaf,
          size: 16,
          color: SeedlingColors.themeGratitude,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    if (PlatformUtils.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AdaptiveIcons.leaf,
                color: SeedlingColors.forestGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text('Seedling'),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Text(
                  'Memory-keeping that feels like breathing, not documenting.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: SeedlingColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seedling is a space for capturing moments that matter to you. '
                  'Not every memory needs explanation. Not every thought needs to be complete.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Watch your tree grow as you plant seeds of memory throughout the year.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Version $_appVersion',
                  style: TextStyle(
                    fontSize: 12,
                    color: SeedlingColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                AdaptiveIcons.leaf,
                color: SeedlingColors.forestGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Seedling'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory-keeping that feels like breathing, not documenting.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Seedling is a space for capturing moments that matter to you. '
                'Not every memory needs explanation. Not every thought needs to be complete.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Watch your tree grow as you plant seeds of memory throughout the year.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Version $_appVersion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SeedlingColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
