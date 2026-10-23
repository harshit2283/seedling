import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/sync/sync_metadata.dart';
import 'package:seedling/core/services/sync/sync_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'a restored install gets a new device id and a clean sync state',
    () async {
      SharedPreferences.setMockInitialValues({'sync_enabled_cloudKit': true});
      final prefs = await SharedPreferences.getInstance();
      final meta = SyncMetadata(prefs, namespace: 'cloudKit');
      final originalId = meta.deviceId;
      await meta.addPendingChange(
        SyncChange(
          syncUUID: '550e8400-e29b-41d4-a716-446655440071',
          changeType: SyncChangeType.update,
          timestamp: DateTime.now(),
        ),
      );
      await meta.setChangeToken('old-token');

      await SyncMetadata.resetForRestoredInstall(prefs);

      expect(meta.deviceId, isNot(originalId));
      expect(meta.pendingChanges, isEmpty);
      expect(meta.changeToken, isNull);
      expect(meta.isEnabled, isTrue); // the user's choice is kept
    },
  );

  test('purged entries are queued as remote deletes immediately', () async {
    SharedPreferences.setMockInitialValues({'sync_enabled_googleDrive': true});
    final prefs = await SharedPreferences.getInstance();
    await SyncMetadata.queuePurgedDeletes(prefs, [
      (
        syncUUID: '550e8400-e29b-41d4-a716-446655440072',
        mediaAssetId: '550e8400-e29b-41d4-a716-446655440073',
      ),
    ]);
    final drive = SyncMetadata(prefs, namespace: 'googleDrive');
    final change = drive.pendingChanges.single;
    expect(change.changeType, SyncChangeType.delete);
    expect(change.mediaAssetId, '550e8400-e29b-41d4-a716-446655440073');
    // Providers whose sync is off are left alone.
    expect(SyncMetadata(prefs, namespace: 'cloudKit').pendingChanges, isEmpty);
  });
}
