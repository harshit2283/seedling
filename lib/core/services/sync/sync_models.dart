/// Current state of cloud sync
enum SyncState { disabled, idle, pushing, pulling, merging, error }

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final int conflictsResolved;
  final String? errorMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.conflictsResolved = 0,
    this.errorMessage,
    required this.timestamp,
  });

  factory SyncResult.success({
    int pushed = 0,
    int pulled = 0,
    int conflicts = 0,
  }) {
    return SyncResult(
      success: true,
      pushedCount: pushed,
      pulledCount: pulled,
      conflictsResolved: conflicts,
      timestamp: DateTime.now(),
    );
  }

  factory SyncResult.error(String message) {
    return SyncResult(
      success: false,
      errorMessage: message,
      timestamp: DateTime.now(),
    );
  }
}

/// A change record for sync queue
class SyncChange {
  final String syncUUID;
  final SyncChangeType changeType;
  final DateTime timestamp;

  const SyncChange({
    required this.syncUUID,
    required this.changeType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'syncUUID': syncUUID,
    'changeType': changeType.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory SyncChange.fromJson(Map<String, dynamic> json) {
    return SyncChange(
      syncUUID: json['syncUUID'] as String,
      changeType: SyncChangeType.values.byName(json['changeType'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}

enum SyncChangeType { create, update, delete }

/// Thrown when the persisted sync document is malformed/corrupted.
class SyncDocumentCorruptedException implements Exception {
  final String operation;
  final String message;
  final String? backupPath;

  const SyncDocumentCorruptedException({
    required this.operation,
    required this.message,
    this.backupPath,
  });

  @override
  String toString() {
    final suffix = backupPath == null ? '' : ' (backup: $backupPath)';
    return 'SyncDocumentCorruptedException[$operation]: $message$suffix';
  }
}

/// Thrown when the user tries to sign in with a different Google account
/// than the one that was locked in for this device.
class AccountMismatchException implements Exception {
  final String lockedAccount;
  final String attemptedAccount;

  const AccountMismatchException({
    required this.lockedAccount,
    required this.attemptedAccount,
  });

  @override
  String toString() =>
      'AccountMismatchException: device is locked to $lockedAccount, '
      'cannot use $attemptedAccount. Reset sync to switch accounts.';
}
