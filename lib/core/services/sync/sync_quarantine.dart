import 'dart:convert';
import 'dart:io';

import 'sync_metadata.dart';

/// Records that could not be decrypted or authenticated (wrong or stale key,
/// damaged or forged data), kept so they can be retried later without
/// blocking the rest of a pull.
///
/// Stored as a file (records are already ciphertext), not in
/// SharedPreferences: it can reach a few MB and is only rewritten when it
/// actually changes. Without a [directory] it is kept in memory only.
class SyncQuarantine {
  static const maxRecords = 500;

  final Future<Directory> Function()? _directory;
  final String _namespace;
  final SyncMetadata? _legacy;
  List<Map<String, dynamic>>? _cache;
  String _savedJson = '[]';

  SyncQuarantine({
    Future<Directory> Function()? directory,
    String namespace = 'default',
    SyncMetadata? legacyMetadata,
  }) : _directory = directory,
       _namespace = namespace,
       _legacy = legacyMetadata;

  /// Records currently set aside (loaded on first use).
  Future<List<Map<String, dynamic>>> records() async {
    final cached = _cache;
    if (cached != null) return cached;
    var loaded = <Map<String, dynamic>>[];
    final file = await _file();
    if (file != null && await file.exists()) {
      try {
        _savedJson = await file.readAsString();
        loaded = [
          for (final r in jsonDecode(_savedJson) as List<dynamic>)
            Map<String, dynamic>.from(r as Map),
        ];
      } catch (_) {
        loaded = [];
      }
    }
    // One-time move out of SharedPreferences (earlier builds kept it there).
    final legacy = await _legacy?.takeLegacyQuarantine() ?? const [];
    _cache = loaded;
    if (legacy.isNotEmpty) await replace([...loaded, ...legacy]);
    return _cache!;
  }

  int get count => _cache?.length ?? 0;

  /// Replaces the set (newest per syncUUID, capped). Writes only on change.
  Future<void> replace(List<Map<String, dynamic>> records) async {
    final byUUID = <String, Map<String, dynamic>>{};
    for (final r in records) {
      final id = r['syncUUID'];
      if (id is String) byUUID[id] = r;
    }
    var kept = byUUID.values.toList();
    if (kept.length > maxRecords) kept = kept.sublist(kept.length - maxRecords);
    _cache = kept;
    final json = jsonEncode(kept);
    if (json == _savedJson) return;
    final file = await _file();
    if (file != null) {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(file.path);
    }
    _savedJson = json;
  }

  Future<File?> _file() async {
    final dirFn = _directory;
    if (dirFn == null) return null;
    final dir = await dirFn();
    return File('${dir.path}/sync_state/quarantine_$_namespace.json');
  }
}
