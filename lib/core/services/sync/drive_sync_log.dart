import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'sync_backend.dart';
import 'sync_models.dart';

/// A file in the remote sync space (Drive appData folder or CloudKit zone).
class DriveFileInfo {
  final String id;
  final String name;

  /// When the file was created, if the store knows (used for age-based
  /// cleanup; files without it are never treated as old).
  final DateTime? createdAt;

  const DriveFileInfo({required this.id, required this.name, this.createdAt});
}

/// The handful of file operations sync needs. Abstracted so the sync
/// protocol is shared by Google Drive and CloudKit and testable without
/// either.
abstract class DriveFileStore {
  /// Files whose name starts with [prefix]. May be expensive (a full scan on
  /// CloudKit): only used when pulling and for maintenance.
  Future<List<DriveFileInfo>> listByPrefix(String prefix);

  /// The file named exactly [name], or null. Cheap.
  Future<DriveFileInfo?> findByName(String name);

  /// Full contents of [fileId], or null if it has no content.
  Future<List<int>?> read(String fileId);

  /// Create a file and return its id.
  Future<String> create(String name, List<int> bytes);

  /// Replace the contents of [fileId].
  Future<void> overwrite(String fileId, List<int> bytes);

  /// Create a file streamed from [source] (for media blobs).
  Future<String> createFromFile(String name, File source);

  /// Replace the contents of [fileId] from [source].
  Future<void> overwriteFromFile(String fileId, File source);

  /// Stream the contents of [fileId] into [target].
  Future<void> downloadTo(String fileId, File target);

  /// Delete [fileId].
  Future<void> delete(String fileId);
}

/// One file of a device's change log: either a compacted base (everything
/// up to [to]) or an append-only chunk covering seqs [from]..[to].
class _LogFile {
  static final _pattern = RegExp(
    r'^seedling_sync_log_v3_([0-9a-fA-F-]{36})_([0-9a-f]{8})_'
    r'(?:b(\d+)|c(\d+)-(\d+))\.json$',
  );

  final DriveFileInfo info;
  final String deviceId;
  final String epoch;
  final bool isBase;
  final int from;
  final int to;

  _LogFile(
    this.info,
    this.deviceId,
    this.epoch,
    this.isBase,
    this.from,
    this.to,
  );

  static _LogFile? parse(DriveFileInfo info) {
    final m = _pattern.firstMatch(info.name);
    if (m == null) return null;
    final base = m.group(3);
    if (base != null) {
      return _LogFile(info, m.group(1)!, m.group(2)!, true, 1, int.parse(base));
    }
    return _LogFile(
      info,
      m.group(1)!,
      m.group(2)!,
      false,
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }
}

typedef _Entry = ({int seq, Map<String, dynamic> record});
typedef _Tombstone = ({int seq, int deletedAt});

/// Contents of one log file.
class _LogBody {
  final Map<String, _Entry> records;
  final Map<String, _Tombstone> deletions;

  _LogBody({Map<String, _Entry>? records, Map<String, _Tombstone>? deletions})
    : records = records ?? {},
      deletions = deletions ?? {};

  Map<String, dynamic> toJson({
    required String deviceId,
    required String epoch,
    required int from,
    required int to,
  }) => {
    'format': 'seedling-sync-log',
    'version': 3,
    'deviceId': deviceId,
    'epoch': epoch,
    'from': from,
    'to': to,
    'records': {
      for (final MapEntry(:key, :value) in records.entries)
        key: {'seq': value.seq, 'record': value.record},
    },
    'deletions': {
      for (final MapEntry(:key, :value) in deletions.entries)
        key: {'seq': value.seq, 'deletedAt': value.deletedAt},
    },
  };

  static _LogBody fromBytes(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (json['format'] != 'seedling-sync-log' || json['version'] != 3) {
      throw const FormatException('Not a v3 seedling sync log');
    }
    final rawRecords = json['records'] as Map<String, dynamic>? ?? {};
    final rawDeletions = json['deletions'] as Map<String, dynamic>? ?? {};
    return _LogBody(
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
  }
}

/// What a device has already read: per device log, the epoch and last seq
/// seen, plus the legacy marker.
class DriveChangeToken {
  final Map<String, ({String epoch, int seq})> seen;
  final int? legacyUpdatedAt;

  const DriveChangeToken({this.seen = const {}, this.legacyUpdatedAt});

  /// Tokens from older layouts or garbage parse as "nothing seen": the next
  /// fetch is a full one, which merging tolerates.
  factory DriveChangeToken.parse(String? raw) {
    if (raw == null || raw.isEmpty) return const DriveChangeToken();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != 3) {
        return const DriveChangeToken();
      }
      final logs = json['logs'] as Map<String, dynamic>? ?? {};
      return DriveChangeToken(
        seen: {
          for (final MapEntry(:key, :value) in logs.entries)
            if (value is String && value.contains(':'))
              key: (
                epoch: value.split(':').first,
                seq: int.tryParse(value.split(':').last) ?? 0,
              ),
        },
        legacyUpdatedAt: (json['legacy'] as num?)?.toInt(),
      );
    } on FormatException {
      return const DriveChangeToken();
    }
  }

  String encode() => jsonEncode({
    'v': 3,
    'logs': {
      for (final MapEntry(:key, :value) in seen.entries)
        key: '${value.epoch}:${value.seq}',
    },
    if (legacyUpdatedAt != null) 'legacy': legacyUpdatedAt,
  });
}

/// Called with raw bytes that could not be parsed, before giving up on them.
typedef DriveCorruptionBackup =
    Future<String?> Function(String operation, List<int> bytes);

/// Reads data left by an older sync layout. Given the marker stored in the
/// change token last time (null = never), it adds records/deletions and
/// returns the new marker (null = nothing read, try again next time).
typedef SyncLegacyReader =
    Future<int?> Function(
      int? seenMarker,
      List<Map<String, dynamic>> records,
      Set<String> deletedUUIDs,
    );

/// The sync protocol over a [DriveFileStore].
///
/// Each device writes only its own change log, so writes never race across
/// devices (neither Drive nor this protocol needs compare-and-swap). Readers
/// ask "what changed since seq N" per log, never comparing clocks.
///
/// A log is `<prefix><device>_<epoch>_b<seq>.json` (a compacted base) plus
/// append-only chunks `..._c<from>-<to>.json`. A push writes one small chunk;
/// after [maxChunks] chunks the device compacts everything into a new base,
/// pruning tombstones older than [tombstoneTtl], and deletes the old files.
/// File names alone tell readers what to download.
///
/// The epoch is random per log lifetime. If a log is lost or restarts (zone
/// wiped, files deleted), it comes back with a new epoch, and readers re-read
/// it from the start instead of waiting for a seq they have already seen.
class DriveSyncLogStore {
  static const logPrefix = 'seedling_sync_log_v3_';

  /// The v1 shared document (released Drive layout). Still read, never
  /// written, so data from older app versions keeps arriving.
  static const legacyFileName = 'seedling_sync_db_v1.json';

  final DriveFileStore _files;
  final String _deviceId;
  final DriveCorruptionBackup? _backup;
  final SyncLegacyReader? _legacy;
  final Duration _keyringSettle;
  final int maxChunks;
  final Duration tombstoneTtl;

  Future<void> _writeTail = Future<void>.value();

  // This device's log, cached for the session (only this device writes it,
  // so there is no need to download it before each push).
  bool _ownLoaded = false;
  String _epoch = '';
  int _seq = 0;
  final Map<String, _Entry> _ownRecords = {};
  final Map<String, _Tombstone> _ownDeletions = {};
  final List<_LogFile> _ownFiles = [];

  DriveSyncLogStore(
    this._files, {
    required String deviceId,
    DriveCorruptionBackup? backup,
    SyncLegacyReader? legacy,
    Duration keyringSettle = const Duration(seconds: 2),
    this.maxChunks = 16,
    this.tombstoneTtl = const Duration(days: 90),
  }) : _deviceId = deviceId,
       _backup = backup,
       _legacy = legacy,
       _keyringSettle = keyringSettle;

  String get _ownPrefix => '$logPrefix${_deviceId}_';

  String _baseName(String epoch, int seq) => '$_ownPrefix${epoch}_b$seq.json';

  String _chunkName(String epoch, int from, int to) =>
      '$_ownPrefix${epoch}_c$from-$to.json';

  static String _newEpoch() {
    final random = Random.secure();
    return List<String>.generate(
      4,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _serializedWrite(Future<void> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Picks the current epoch of a device's files: the one reaching the
  /// highest seq. Returns its files (deduplicated by name).
  static List<_LogFile> _currentEpoch(List<_LogFile> files) {
    if (files.isEmpty) return const [];
    final best = <String, int>{};
    for (final f in files) {
      best[f.epoch] = max(best[f.epoch] ?? 0, f.to);
    }
    final epoch =
        (best.entries.toList()..sort((a, b) {
              final bySeq = b.value.compareTo(a.value);
              return bySeq != 0 ? bySeq : a.key.compareTo(b.key);
            }))
            .first
            .key;
    final byName = <String, _LogFile>{};
    for (final f in files.where((f) => f.epoch == epoch)) {
      byName.putIfAbsent(f.info.name, () => f);
    }
    return byName.values.toList();
  }

  /// Reads the files of one log needed to go past [since]: the newest base
  /// if [since] is before it, then contiguous chunks. Stops at the first gap
  /// or unreadable file, so the returned seq never skips anything.
  Future<({int seq, _LogBody body})> _readLog(
    List<_LogFile> files,
    int since,
  ) async {
    final bases = files.where((f) => f.isBase).toList()
      ..sort((a, b) => b.to.compareTo(a.to));
    final body = _LogBody();
    var reached = since;
    if (bases.isNotEmpty && bases.first.to > since) {
      final base = bases.first;
      final bytes = await _files.read(base.info.id);
      if (bytes == null) return (seq: since, body: _LogBody());
      final parsed = _LogBody.fromBytes(bytes);
      _mergeInto(body, parsed, since);
      reached = base.to;
    }
    final chunks = files.where((f) => !f.isBase && f.to > reached).toList()
      ..sort((a, b) => a.from.compareTo(b.from));
    for (final chunk in chunks) {
      if (chunk.from > reached + 1) break; // gap: wait for the next pull
      if (chunk.to <= reached) continue;
      final bytes = await _files.read(chunk.info.id);
      if (bytes == null) break; // compacted away meanwhile
      _mergeInto(body, _LogBody.fromBytes(bytes), since);
      reached = chunk.to;
    }
    return (seq: reached, body: body);
  }

  static void _mergeInto(_LogBody into, _LogBody from, int since) {
    for (final MapEntry(:key, :value) in from.records.entries) {
      if (value.seq <= since) continue;
      final existing = into.records[key];
      final tomb = into.deletions[key];
      if ((existing == null || existing.seq < value.seq) &&
          (tomb == null || tomb.seq < value.seq)) {
        into.records[key] = value;
        into.deletions.remove(key);
      }
    }
    for (final MapEntry(:key, :value) in from.deletions.entries) {
      if (value.seq <= since) continue;
      final existing = into.records[key];
      final tomb = into.deletions[key];
      if ((existing == null || existing.seq < value.seq) &&
          (tomb == null || tomb.seq < value.seq)) {
        into.deletions[key] = value;
        into.records.remove(key);
      }
    }
  }

  Future<void> _loadOwn() async {
    if (_ownLoaded) return;
    final files = [
      for (final info in await _files.listByPrefix(_ownPrefix))
        ?_LogFile.parse(info),
    ].where((f) => f.deviceId == _deviceId).toList();
    final current = _currentEpoch(files);
    if (current.isEmpty) {
      _epoch = _newEpoch();
      _seq = 0;
    } else {
      final read = await _readLog(current, 0);
      final maxSeq = current.map((f) => f.to).reduce(max);
      if (read.seq != maxSeq) {
        // Refuse to write on top of a log we couldn't fully read: that would
        // shadow changes other devices haven't seen yet.
        throw const SyncDocumentCorruptedException(
          operation: 'load',
          message: "This device's sync log could not be read completely",
        );
      }
      _epoch = current.first.epoch;
      _seq = read.seq;
      _ownRecords.addAll(read.body.records);
      _ownDeletions.addAll(read.body.deletions);
      _ownFiles.addAll(current);
    }
    _ownLoaded = true;
  }

  /// Append records and deletions to this device's log as one chunk.
  Future<void> append({
    List<Map<String, dynamic>> records = const [],
    List<String> deletions = const [],
    DateTime? now,
  }) {
    if (records.isEmpty && deletions.isEmpty) return Future<void>.value();
    return _serializedWrite(() async {
      await _loadOwn();
      final chunk = _LogBody();
      var seq = _seq;
      for (final record in records) {
        final syncUUID = record['syncUUID'] as String?;
        if (syncUUID == null || syncUUID.isEmpty) {
          throw ArgumentError('syncUUID is required');
        }
        chunk.records[syncUUID] = (
          seq: ++seq,
          record: Map<String, dynamic>.from(record),
        );
        chunk.deletions.remove(syncUUID);
      }
      final deletedAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
      for (final syncUUID in deletions) {
        chunk.deletions[syncUUID] = (seq: ++seq, deletedAt: deletedAt);
        chunk.records.remove(syncUUID);
      }
      final from = _seq + 1;
      final name = _chunkName(_epoch, from, seq);
      // Same name on a retry (state only advances after success), so a
      // duplicate from a retried create has identical content.
      final id = await _files.create(
        name,
        utf8.encode(
          jsonEncode(
            chunk.toJson(
              deviceId: _deviceId,
              epoch: _epoch,
              from: from,
              to: seq,
            ),
          ),
        ),
      );
      _seq = seq;
      _mergeInto(
        _LogBody(records: _ownRecords, deletions: _ownDeletions),
        chunk,
        0,
      );
      _ownFiles.add(
        _LogFile(
          DriveFileInfo(id: id, name: name),
          _deviceId,
          _epoch,
          false,
          from,
          seq,
        ),
      );
      if (_ownFiles.where((f) => !f.isBase).length >= maxChunks) {
        await _compact(now ?? DateTime.now());
      }
    });
  }

  /// Rewrites this device's log as one base file and deletes the old files.
  Future<void> _compact(DateTime now) async {
    final cutoff = now.subtract(tombstoneTtl).millisecondsSinceEpoch;
    _ownDeletions.removeWhere((_, t) => t.deletedAt < cutoff);
    final name = _baseName(_epoch, _seq);
    final body = _LogBody(records: _ownRecords, deletions: _ownDeletions);
    final id = await _files.create(
      name,
      utf8.encode(
        jsonEncode(
          body.toJson(deviceId: _deviceId, epoch: _epoch, from: 1, to: _seq),
        ),
      ),
    );
    final old = List<_LogFile>.of(_ownFiles);
    _ownFiles
      ..clear()
      ..add(
        _LogFile(
          DriveFileInfo(id: id, name: name),
          _deviceId,
          _epoch,
          true,
          1,
          _seq,
        ),
      );
    for (final f in old) {
      try {
        await _files.delete(f.info.id);
      } catch (e) {
        developer.log(
          'Old log file not deleted',
          name: 'DriveSyncLogStore',
          error: e,
        );
      }
    }
  }

  /// Everything written since [changeToken], from every device's log (and
  /// the legacy layout).
  Future<SyncFetchResult> fetch(String? changeToken) async {
    final token = DriveChangeToken.parse(changeToken);
    final seen = Map<String, ({String epoch, int seq})>.of(token.seen);
    final records = <Map<String, dynamic>>[];
    final deletedUUIDs = <String>{};

    final byDevice = <String, List<_LogFile>>{};
    for (final info in await _files.listByPrefix(logPrefix)) {
      final f = _LogFile.parse(info);
      if (f != null) (byDevice[f.deviceId] ??= []).add(f);
    }

    for (final MapEntry(key: device, value: all) in byDevice.entries) {
      final files = _currentEpoch(all);
      final epoch = files.first.epoch;
      final maxSeq = files.map((f) => f.to).reduce(max);
      final previous = seen[device];
      // Our own pushes are applied locally already; read our log only once
      // (e.g. after a reinstall that kept the device id).
      if (device == _deviceId && previous != null && previous.epoch == epoch) {
        seen[device] = (epoch: epoch, seq: maxSeq);
        continue;
      }
      // New epoch, or a seq that went backwards: the log restarted, so read
      // it from the beginning.
      final since =
          (previous == null || previous.epoch != epoch || previous.seq > maxSeq)
          ? 0
          : previous.seq;
      if (since >= maxSeq) continue;
      try {
        final read = await _readLog(files, since);
        records.addAll(read.body.records.values.map((e) => e.record));
        deletedUUIDs.addAll(read.body.deletions.keys);
        if (read.seq > since || previous?.epoch != epoch) {
          seen[device] = (epoch: epoch, seq: read.seq);
        }
      } catch (error) {
        // One damaged log must not block everyone else's changes; it is
        // retried next time (its seen seq doesn't move).
        developer.log(
          'Skipping unreadable sync log of $device',
          name: 'DriveSyncLogStore',
          error: error,
        );
      }
    }

    final legacyMarker = await (_legacy ?? _readLegacyDocumentChanges)(
      token.legacyUpdatedAt,
      records,
      deletedUUIDs,
    );

    return SyncFetchResult(
      records: records,
      deletedUUIDs: deletedUUIDs.toList(),
      newChangeToken: DriveChangeToken(
        seen: seen,
        legacyUpdatedAt: legacyMarker ?? token.legacyUpdatedAt,
      ).encode(),
    );
  }

  /// Devices (other than this one) whose newest log file is older than
  /// [idle]. Their logs can be retired once their data lives in this
  /// device's log.
  Future<List<String>> idleDevices(Duration idle, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(idle);
    final newest = <String, DateTime?>{};
    final unknownAge = <String>{};
    for (final info in await _files.listByPrefix(logPrefix)) {
      final f = _LogFile.parse(info);
      if (f == null || f.deviceId == _deviceId) continue;
      final at = info.createdAt;
      if (at == null) {
        unknownAge.add(f.deviceId);
        continue;
      }
      final prev = newest[f.deviceId];
      if (prev == null || at.isAfter(prev)) newest[f.deviceId] = at;
    }
    return [
      for (final MapEntry(:key, :value) in newest.entries)
        if (!unknownAge.contains(key) &&
            value != null &&
            value.isBefore(cutoff))
          key,
    ];
  }

  /// Deletes every log file of [deviceIds] (never keyrings).
  Future<void> deleteDeviceLogs(List<String> deviceIds) async {
    if (deviceIds.isEmpty) return;
    for (final info in await _files.listByPrefix(logPrefix)) {
      final f = _LogFile.parse(info);
      if (f != null && deviceIds.contains(f.deviceId)) {
        await _files.delete(info.id);
      }
    }
  }

  /// Reads the v1 shared document when it changed since last time. All of
  /// its records are delivered again (merging is idempotent, so that is
  /// safe); deletions only when newer than what we saw last, so an old
  /// tombstone can't re-delete an entry restored since.
  Future<int?> _readLegacyDocumentChanges(
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
    final file = await _files.findByName(legacyFileName);
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

  /// Keyring files: `{kdfSalt, check}` - the account's random key salt and
  /// an encrypted key-check value that proves a passphrase is right. Several
  /// can exist if devices enabled sync at the same moment (no create-if-
  /// absent on Drive); every reader picks the same one, the smallest salt
  /// (preferring a copy that carries a check), so all devices agree.
  static const keyringPrefix = 'seedling_sync_keyring_v1';

  String get _ownKeyringName => '${keyringPrefix}_$_deviceId.json';

  /// The keyring every device uses, or null if none exists yet.
  Future<Map<String, dynamic>?> readKeyring() async {
    final candidates = <Map<String, dynamic>>[];
    for (final file in await _files.listByPrefix(keyringPrefix)) {
      final bytes = await _files.read(file.id);
      if (bytes == null || bytes.isEmpty) continue;
      try {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final salt = json['kdfSalt'] as String?;
        if (salt != null && base64Decode(salt).length >= 16) {
          candidates.add(json);
        }
      } catch (_) {
        continue;
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final bySalt = (a['kdfSalt'] as String).compareTo(b['kdfSalt'] as String);
      if (bySalt != 0) return bySalt;
      return (a['check'] == null ? 1 : 0) - (b['check'] == null ? 1 : 0);
    });
    return candidates.first;
  }

  /// Publishes [keyring] unless one exists, then returns the keyring in
  /// effect. After writing, it re-reads until two reads agree (bounded), so
  /// a device that raced another settles on the winner *before* it derives
  /// a key and pushes anything. An existing keyring with the same salt but
  /// no key check gets [keyring]'s check added.
  Future<Map<String, dynamic>> publishKeyring(
    Map<String, dynamic> keyring,
  ) async {
    final existing = await readKeyring();
    if (existing != null) {
      final addsCheck =
          existing['check'] == null &&
          keyring['check'] != null &&
          existing['kdfSalt'] == keyring['kdfSalt'];
      if (!addsCheck) return existing;
    }
    final bytes = utf8.encode(
      jsonEncode({'v': 1, 'kdf': 'pbkdf2-sha256', ...keyring}),
    );
    final own = await _files.findByName(_ownKeyringName);
    if (own == null) {
      await _files.create(_ownKeyringName, bytes);
    } else {
      await _files.overwrite(own.id, bytes);
    }
    var current = await readKeyring() ?? keyring;
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(_keyringSettle);
      final again = await readKeyring() ?? keyring;
      if (again['kdfSalt'] == current['kdfSalt']) return again;
      current = again;
    }
    return current;
  }

  /// Encrypted media blobs, one file per asset id.
  static const mediaPrefix = 'seedling_media_v1_';

  static String _blobName(String assetId) {
    // Ids end up in Drive query strings; only allow UUIDs.
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(assetId)) {
      throw ArgumentError.value(assetId, 'assetId', 'must be a UUID');
    }
    return '$mediaPrefix$assetId.bin';
  }

  static String? _assetIdOf(String name) {
    if (!name.startsWith(mediaPrefix) || !name.endsWith('.bin')) return null;
    return name.substring(mediaPrefix.length, name.length - 4);
  }

  /// Uploads a blob. A retry of an interrupted upload reuses its asset id
  /// and passes [replace] so the (re-encrypted) content replaces whatever
  /// partial or stale copy exists.
  Future<void> uploadBlob(
    String assetId,
    File ciphertext, {
    bool replace = false,
  }) async {
    final name = _blobName(assetId);
    final existing = await _files.findByName(name);
    if (existing == null) {
      await _files.createFromFile(name, ciphertext);
    } else if (replace) {
      await _files.overwriteFromFile(existing.id, ciphertext);
    }
  }

  Future<bool> downloadBlob(String assetId, File target) async {
    final blob = await _files.findByName(_blobName(assetId));
    if (blob == null) return false;
    await _files.downloadTo(blob.id, target);
    return true;
  }

  Future<void> deleteBlob(String assetId) async {
    final blob = await _files.findByName(_blobName(assetId));
    if (blob != null) await _files.delete(blob.id);
  }

  /// Deletes blobs that no record references and that are older than
  /// [minAge] (younger ones may belong to a push still in flight on another
  /// device). Returns how many were deleted.
  Future<int> deleteOrphanBlobs(
    Set<String> referenced, {
    Duration minAge = const Duration(days: 7),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    var deleted = 0;
    for (final info in await _files.listByPrefix(mediaPrefix)) {
      final id = _assetIdOf(info.name);
      final created = info.createdAt;
      if (id == null || referenced.contains(id) || created == null) continue;
      if (!created.isBefore(cutoff)) continue;
      await _files.delete(info.id);
      deleted++;
    }
    return deleted;
  }
}
