import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/constants/prefs_keys.dart';
import 'package:seedling/core/services/providers.dart';
import 'package:seedling/core/services/sync/sync_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend that records every account-API call so tests can assert none
/// happen before the user opts in to cloud sync.
class _CountingBackend extends SyncBackend {
  int availabilityCalls = 0;
  int statusCalls = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityCalls++;
    return true;
  }

  @override
  Future<String> getAccountStatus() async {
    statusCalls++;
    return 'someone@example.com';
  }

  @override
  Future<void> saveRecord(Map<String, dynamic> record) async {}

  @override
  Future<void> deleteRecord(String syncUUID) async {}

  @override
  Future<SyncFetchResult?> fetchChanges({String? changeToken}) async => null;
}

Future<ProviderContainer> _container(
  _CountingBackend backend, {
  required bool optedIn,
}) async {
  SharedPreferences.setMockInitialValues({PrefsKeys.cloudSyncEnabled: optedIn});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncBackendProvider.overrideWithValue(backend),
    ],
  );
}

void main() {
  test('account providers never touch the backend before opt-in', () async {
    final backend = _CountingBackend();
    final container = await _container(backend, optedIn: false);
    addTearDown(container.dispose);

    expect(await container.read(syncAccountConnectedProvider.future), isFalse);
    expect(
      await container.read(syncAccountStatusProvider.future),
      syncAccountStatusOptedOut,
    );
    expect(backend.availabilityCalls, 0);
    expect(backend.statusCalls, 0);
  });

  test('account providers query the backend once opted in', () async {
    final backend = _CountingBackend();
    final container = await _container(backend, optedIn: true);
    addTearDown(container.dispose);

    expect(await container.read(syncAccountConnectedProvider.future), isTrue);
    expect(
      await container.read(syncAccountStatusProvider.future),
      'someone@example.com',
    );
    expect(backend.availabilityCalls, 1);
    expect(backend.statusCalls, 1);
  });

  test('flipping opt-in on re-evaluates the gated providers', () async {
    final backend = _CountingBackend();
    final container = await _container(backend, optedIn: false);
    addTearDown(container.dispose);

    expect(await container.read(syncAccountConnectedProvider.future), isFalse);
    await container.read(cloudSyncEnabledProvider.notifier).setEnabled(true);
    expect(await container.read(syncAccountConnectedProvider.future), isTrue);
    expect(backend.availabilityCalls, 1);
  });
}
