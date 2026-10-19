import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'sync_backend.dart';
import 'sync_models.dart';

/// A file in the Drive appData folder.
class DriveFileInfo {
  final String id;
  final String name;

  const DriveFileInfo({required this.id, required this.name});
}

/// The handful of Drive file operations sync needs. Abstracted so the sync
/// protocol can be tested without Google sign-in.
abstract class DriveFileStore {
  /// Files whose name starts with [prefix].
  Future<List<DriveFileInfo>> listByPrefix(String prefix);

  /// Full contents of [fileId], or null if it has no content.
  Future<List<int>?> read(String fileId);

  /// Create a file and return its id.
  Future<String> create(String name, List<int> bytes);

  /// Replace the contents of [fileId].
  Future<void> overwrite(String fileId, List<int> bytes);
}

/// One device's change log.
///
/// Why per-device files: Drive has no conditional (compare-and-swap) update,
/// so a single shared document rewritten by every device loses whichever
/// push lands first when two devices write at once. Here each device only
/// ever writes its own log, so writes never race across devices.
///
/// Why sequence numbers: readers ask "what changed since I last looked" by
/// [seq], a counter only the owning device increments when it pushes.
/// Comparing timestamps from different devices' clocks (the old scheme)
/// skipped offline edits and anything written by a device whose clock ran
/// behind.
class DriveSyncLog {
  static const format = 'seedling-sync-log';
  static const version = 2;

  final String deviceId;
  int seq;

  /// syncUUID -> {seq, record}
  final Map<String, ({int seq, Map<String, dynamic> record})> records;

  /// syncUUID -> {seq, deletedAt}
  final Map<String, ({int seq, int deletedAt})> deletions;

  DriveSyncLog({
    required this.deviceId,
    this.seq = 0,
    Map<String, ({int seq, Map<String, dynamic> record})>? records,
    Map<String, ({int seq, int deletedAt})>? deletions,
  }) : records = records ?? {},
       deletions = deletions ?? {};

  void putRecord(Map<String, dynamic> record) {
    final syncUUID = record['syncUUID'] as String?;
    if (syncUUID == null || syncUUID.isEmpty) {
      throw ArgumentError('syncUUID is required');
    }
    seq++;
    records[syncUUID] = (seq: seq, record: Map<String, dynamic>.from(record));
    deletions.remove(syncUUID);
  }

  void putDeletion(String syncUUID, {required int deletedAt}) {
    seq++;
    records.remove(syncUUID);
    deletions[syncUUID] = (seq: seq, deletedAt: deletedAt);
  }

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'deviceId': deviceId,
    'seq': seq,
    'records': {
      for (final MapEntry(:key, :value) in records.entries)
        key: {'seq': value.seq, 'record': value.record},
    },
    'deletions': {
      for (final MapEntry(:key, :value) in deletions.entries)
        key: {'seq': value.seq, 'deletedAt': value.deletedAt},
    },
  };

  factory DriveSyncLog.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Not a seedling sync log');
    }
    final rawRecords = json['records'] as Map<String, dynamic>? ?? {};
    final rawDeletions = json['deletions'] as Map<String, dynamic>? ?? {};
    final log = DriveSyncLog(
      deviceId: json['deviceId'] as String,
      seq: (json['seq'] as num).toInt(),
      records: {
        for (final MapEntry(:key, :value) in rawRecords.entries)
          key: (
            seq: ((value as Map)['seq'] as num).toInt(),
            record: Map<String, dynamic>.from(
              (value['record'] as Map).cast<String, dynamic>(),
            ),
          ),
      },
      deletions: {
        for (final MapEntry(:key, :value) in rawDeletions.entries)
          key: (
            seq: ((value as Map)['seq'] as num).toInt(),
            deletedAt: (value['deletedAt'] as num).toInt(),
          ),
      },
    );
    // Never let the counter fall behind an entry (it must stay monotonic).
    for (final s in [
      ...log.records.values.map((r) => r.seq),
      ...log.deletions.values.map((d) => d.seq),
    ]) {
      if (s > log.seq) log.seq = s;
    }
    return log;
  }
}

/// What a device has already read: the last seq seen per log file, plus the
/// legacy (v1 shared document) state.
class DriveChangeToken {
  final Map<String, int> seenSeqByLog;
  final int? legacyUpdatedAt;

  const DriveChangeToken({this.seenSeqByLog = const {}, this.legacyUpdatedAt});

  /// Tokens from the old scheme (a bare timestamp) or garbage parse as
  /// "nothing seen": the next fetch is a full one, which merging tolerates.
  factory DriveChangeToken.parse(String? raw) {
    if (raw == null || raw.isEmpty) return const DriveChangeToken();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != 2) {
        return const DriveChangeToken();
      }
      return DriveChangeToken(
        seenSeqByLog: (json['logs'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
        legacyUpdatedAt: (json['legacy'] as num?)?.toInt(),
      );
    } on FormatException {
      return const DriveChangeToken();
    }
  }

  String encode() => jsonEncode({
    'v': 2,
    'logs': seenSeqByLog,
    if (legacyUpdatedAt != null) 'legacy': legacyUpdatedAt,
  });
}

/// Called with raw bytes that could not be parsed, before giving up on them.
typedef DriveCorruptionBackup =
    Future<String?> Function(String operation, List<int> bytes);

/// The Drive sync protocol over a [DriveFileStore].
class DriveSyncLogStore {
  static const logPrefix = 'seedling_sync_log_v2_';

  /// The v1 shared document. Still read (never written by sync) so data from
  /// older app versions keeps arriving.
  static const legacyFileName = 'seedling_sync_db_v1.json';

  final DriveFileStore _files;
  final String _deviceId;
  final DriveCorruptionBackup? _backup;

  String? _ownLogId;
  Future<void> _writeTail = Future<void>.value();

  DriveSyncLogStore(
    this._files, {
    required String deviceId,
    DriveCorruptionBackup? backup,
  }) : _deviceId = deviceId,
       _backup = backup;

  String get ownLogName => '$logPrefix$_deviceId.json';

  /// Append records and deletions to this device's log in one write.
  Future<void> append({
    List<Map<String, dynamic>> records = const [],
    List<String> deletions = const [],
    DateTime? now,
  }) {
    if (records.isEmpty && deletions.isEmpty) return Future<void>.value();
    return _serializedWrite(() async {
      final log = await _loadOwnLog();
      for (final record in records) {
        log.putRecord(record);
      }
      final deletedAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
      for (final syncUUID in deletions) {
        log.putDeletion(syncUUID, deletedAt: deletedAt);
      }
      final bytes = utf8.encode(jsonEncode(log.toJson()));
      final id = _ownLogId;
      if (id == null) {
        _ownLogId = await _files.create(ownLogName, bytes);
      } else {
        await _files.overwrite(id, bytes);
      }
    });
  }

  Future<void> _serializedWrite(Future<void> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<DriveSyncLog> _loadOwnLog() async {
    // Always re-read: the remote copy is the source of truth for our seq.
    final files = await _files.listByPrefix(ownLogName);
    final own = files.where((f) => f.name == ownLogName).firstOrNull;
    if (own == null) {
      _ownLogId = null;
      return DriveSyncLog(deviceId: _deviceId);
    }
    _ownLogId = own.id;
    final bytes = await _files.read(own.id);
    if (bytes == null || bytes.isEmpty) {
      return DriveSyncLog(deviceId: _deviceId);
    }
    try {
      return DriveSyncLog.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } catch (error) {
      // Refuse to overwrite our own log with a fresh one: that would drop
      // every change other devices haven't read yet.
      final backupPath = await _backup?.call('own_log_corrupt', bytes);
      throw SyncDocumentCorruptedException(
        operation: 'load',
        message: 'Unable to decode this device\'s sync log: $error',
        backupPath: backupPath,
      );
    }
  }

  /// Everything written since [changeToken], from every device's log (and
  /// the legacy document).
  Future<SyncFetchResult> fetch(String? changeToken) async {
    final token = DriveChangeToken.parse(changeToken);
    final seen = Map<String, int>.of(token.seenSeqByLog);
    final records = <Map<String, dynamic>>[];
    final deletedUUIDs = <String>{};

    for (final file in await _files.listByPrefix(logPrefix)) {
      final since = seen[file.name];
      // Our own pushes are already applied locally; read our log only once
      // (e.g. after a reinstall that kept the device id).
      if (file.name == ownLogName && since != null) continue;
      final bytes = await _files.read(file.id);
      if (bytes == null || bytes.isEmpty) continue;
      final DriveSyncLog log;
      try {
        log = DriveSyncLog.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        );
      } catch (error) {
        // One damaged log must not block everyone else's changes. It is
        // retried next time (its seen seq doesn't move).
        await _backup?.call('fetch_log_corrupt', bytes);
        developer.log(
          'Skipping unreadable sync log ${file.name}',
          name: 'DriveSyncLogStore',
          error: error,
        );
        continue;
      }
      final from = since ?? 0;
      for (final entry in log.records.values) {
        if (entry.seq > from) records.add(entry.record);
      }
      for (final MapEntry(:key, :value) in log.deletions.entries) {
        if (value.seq > from) deletedUUIDs.add(key);
      }
      seen[file.name] = log.seq;
    }

    final legacyUpdatedAt = await _readLegacy(
      token.legacyUpdatedAt,
      records,
      deletedUUIDs,
    );

    return SyncFetchResult(
      records: records,
      deletedUUIDs: deletedUUIDs.toList(),
      newChangeToken: DriveChangeToken(
        seenSeqByLog: seen,
        legacyUpdatedAt: legacyUpdatedAt ?? token.legacyUpdatedAt,
      ).encode(),
    );
  }

  /// Reads the v1 shared document when it changed since last time. All of
  /// its records are delivered again (merging is idempotent, so that is
  /// safe); deletions only when newer than what we saw last, so an old
  /// tombstone can't re-delete an entry restored since.
  Future<int?> _readLegacy(
    int? seenUpdatedAt,
    List<Map<String, dynamic>> records,
    Set<String> deletedUUIDs,
  ) async {
    final doc = await readLegacyDocument();
    if (doc == null) return null;
    final updatedAt = (doc['updatedAt'] as num?)?.toInt() ?? 0;
    if (seenUpdatedAt != null && updatedAt == seenUpdatedAt) return updatedAt;

    final rawRecords = doc['records'] as Map<String, dynamic>? ?? {};
    for (final value in rawRecords.values) {
      if (value is Map) {
        records.add(Map<String, dynamic>.from(value.cast<String, dynamic>()));
      }
    }
    final rawDeletions = doc['deletions'] as Map<String, dynamic>? ?? {};
    for (final MapEntry(:key, :value) in rawDeletions.entries) {
      final at = value is num ? value.toInt() : 0;
      if (seenUpdatedAt == null || at > seenUpdatedAt) deletedUUIDs.add(key);
    }
    return updatedAt;
  }

  /// The decoded legacy document, or null when absent/unreadable.
  Future<Map<String, dynamic>?> readLegacyDocument() async {
    final file = (await _files.listByPrefix(
      legacyFileName,
    )).where((f) => f.name == legacyFileName).firstOrNull;
    if (file == null) return null;
    final bytes = await _files.read(file.id);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (error) {
      await _backup?.call('legacy_document_corrupt', bytes);
      return null;
    }
  }

  /// Rewrites the legacy document with [quarantine] cleared.
  Future<void> clearLegacyQuarantine() async {
    final file = (await _files.listByPrefix(
      legacyFileName,
    )).where((f) => f.name == legacyFileName).firstOrNull;
    final doc = await readLegacyDocument();
    if (file == null || doc == null) return;
    doc['quarantine'] = <String, dynamic>{};
    await _files.overwrite(file.id, utf8.encode(jsonEncode(doc)));
  }
}
