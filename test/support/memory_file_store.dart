import 'dart:io';

import 'package:seedling/core/services/sync/drive_sync_log.dart';

/// In-memory sync file store (Drive appData / CloudKit zone stand-in).
/// Every call yields to the event loop first, so concurrent pushes from
/// several "devices" genuinely interleave. Names need not be unique, like
/// Drive.
class MemoryFileStore implements DriveFileStore {
  final files =
      <String, ({String name, List<int> bytes, DateTime createdAt})>{};
  var _nextId = 0;
  var listCalls = 0;
  DateTime Function() now = DateTime.now;

  Future<void> _yield() => Future<void>.delayed(Duration.zero);

  DriveFileInfo _info(String id) => DriveFileInfo(
    id: id,
    name: files[id]!.name,
    createdAt: files[id]!.createdAt,
  );

  Iterable<String> namesWithPrefix(String prefix) =>
      files.values.map((f) => f.name).where((n) => n.startsWith(prefix));

  @override
  Future<List<DriveFileInfo>> listByPrefix(String prefix) async {
    await _yield();
    listCalls++;
    return [
      for (final MapEntry(:key, :value) in files.entries)
        if (value.name.startsWith(prefix)) _info(key),
    ];
  }

  @override
  Future<DriveFileInfo?> findByName(String name) async {
    await _yield();
    for (final MapEntry(:key, :value) in files.entries) {
      if (value.name == name) return _info(key);
    }
    return null;
  }

  @override
  Future<List<int>?> read(String fileId) async {
    await _yield();
    return files[fileId]?.bytes;
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    await _yield();
    final id = 'f${_nextId++}';
    files[id] = (name: name, bytes: List<int>.of(bytes), createdAt: now());
    return id;
  }

  @override
  Future<void> overwrite(String fileId, List<int> bytes) async {
    await _yield();
    final f = files[fileId]!;
    files[fileId] = (
      name: f.name,
      bytes: List<int>.of(bytes),
      createdAt: f.createdAt,
    );
  }

  @override
  Future<String> createFromFile(String name, File source) async =>
      create(name, await source.readAsBytes());

  @override
  Future<void> overwriteFromFile(String fileId, File source) async =>
      overwrite(fileId, await source.readAsBytes());

  @override
  Future<void> downloadTo(String fileId, File target) async {
    await _yield();
    await target.writeAsBytes(files[fileId]!.bytes);
  }

  @override
  Future<void> delete(String fileId) async {
    await _yield();
    files.remove(fileId);
  }
}
