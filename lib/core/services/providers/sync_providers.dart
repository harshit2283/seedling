import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../sync/cloudkit_sync_service.dart';
import '../sync/google_drive_sync_service.dart';
import '../sync/sync_backend.dart';
import '../sync/sync_crypto_service.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_metadata.dart';
import '../sync/sync_models.dart';
import '../../constants/prefs_keys.dart';
import 'database_providers.dart';
import 'media_providers.dart';

// ============================================================================
// Cloud Sync Providers (Phase 5)
// ============================================================================

/// iOS sync provider preference (Android always uses Google Drive).
class SyncProviderNotifier extends Notifier<SyncProviderType> {

  @override
  SyncProviderType build() {
    if (!Platform.isIOS) return SyncProviderType.googleDrive;
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(PrefsKeys.syncProviderIOS);
    if (raw == SyncProviderType.googleDrive.name) {
      return SyncProviderType.googleDrive;
    }
    return SyncProviderType.cloudKit;
  }

  Future<void> setProvider(SyncProviderType provider) async {
    if (!Platform.isIOS) return;
    state = provider;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(PrefsKeys.syncProviderIOS, provider.name);
  }
}

final syncProviderTypeProvider =
    NotifierProvider<SyncProviderNotifier, SyncProviderType>(
      SyncProviderNotifier.new,
    );

/// Provider for the CloudKit sync service (native bridge).
final cloudKitSyncServiceProvider = Provider<CloudKitSyncService>((ref) {
  return CloudKitSyncService();
});

/// Provider for secure storage used by sync cryptography.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for sync payload encryption/decryption.
final syncCryptoServiceProvider = Provider<SyncCryptoService>((ref) {
  return SyncCryptoService(secureStorage: ref.watch(secureStorageProvider));
});

/// Whether a sync passphrase-derived key is configured.
final syncPassphraseConfiguredProvider = FutureProvider<bool>((ref) async {
  return ref.watch(syncCryptoServiceProvider).hasPassphrase();
});

/// Provider for the Google Drive sync service (cross-platform).
final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService();
});

/// Provider for the selected sync backend.
final syncBackendProvider = Provider<SyncBackend>((ref) {
  final providerType = ref.watch(syncProviderTypeProvider);
  if (!Platform.isIOS) {
    return ref.watch(googleDriveSyncServiceProvider);
  }
  return providerType == SyncProviderType.cloudKit
      ? ref.watch(cloudKitSyncServiceProvider)
      : ref.watch(googleDriveSyncServiceProvider);
});

/// Provider for sync metadata (change tokens, pending queue), namespaced by provider.
final syncMetadataProvider = Provider<SyncMetadata>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final providerType = ref.watch(syncProviderTypeProvider);
  return SyncMetadata(prefs, namespace: providerType.name);
});

/// Provider for current sync backend account status text.
final syncAccountStatusProvider = FutureProvider<String>((ref) async {
  final backend = ref.watch(syncBackendProvider);
  return backend.getAccountStatus();
});

/// Provider for whether backend account/session is currently available.
final syncAccountConnectedProvider = FutureProvider<bool>((ref) async {
  final backend = ref.watch(syncBackendProvider);
  return backend.isAvailable();
});

/// Provider for the sync engine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final fileStorage = ref.watch(fileStorageServiceProvider);
  final engine = SyncEngine(
    database: ref.watch(databaseProvider),
    backend: ref.watch(syncBackendProvider),
    metadata: ref.watch(syncMetadataProvider),
    cryptoService: ref.watch(syncCryptoServiceProvider),
    mediaBasePath: fileStorage.basePath,
  );
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Provider for current sync state
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.stateStream;
});

/// Provider for whether sync is enabled
final syncEnabledProvider = Provider<bool>((ref) {
  final metadata = ref.watch(syncMetadataProvider);
  return metadata.isEnabled;
});
