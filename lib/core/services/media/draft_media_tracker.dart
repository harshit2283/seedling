import 'package:flutter/foundation.dart';

/// Deletes a media file; returns whether something was removed.
typedef MediaDeleter = Future<bool> Function(String path);

/// Tracks media files captured into a draft that has not been saved yet.
///
/// Capturing a photo or voice memo writes it straight into the media store,
/// so every photo that is removed, replaced or left behind when the draft is
/// discarded must be deleted explicitly, or it stays on disk forever with no
/// entry pointing at it.
///
/// [deleterFactory] is resolved lazily on the first capture so drafts that
/// never touch media never need a file store.
class DraftMediaTracker {
  DraftMediaTracker(this._deleterFactory);

  final MediaDeleter Function() _deleterFactory;
  MediaDeleter? _deleter;

  static final Map<String, int> _live = {};

  /// Media paths held by any open draft right now. The orphan sweep must
  /// never delete these: no entry references them yet.
  static Set<String> get liveDraftPaths => Set.unmodifiable(_live.keys);

  static void _retain(String path) =>
      _live.update(path, (n) => n + 1, ifAbsent: () => 1);

  static void _release(String path) {
    final n = _live[path];
    if (n == null) return;
    if (n <= 1) {
      _live.remove(path);
    } else {
      _live[path] = n - 1;
    }
  }

  final Set<String> _pending = {};
  bool _settled = false;

  /// Paths captured but not yet saved or released.
  Set<String> get pending => Set.unmodifiable(_pending);

  /// Records that a draft slot changed from [previous] to [next] (a capture,
  /// a replacement, or a removal when [next] is null). The file the slot no
  /// longer references is deleted right away.
  Future<void> update({String? previous, String? next}) async {
    if (next != null && next.isNotEmpty) {
      _deleter ??= _deleterFactory();
      if (_pending.add(next)) _retain(next);
    }
    if (previous != null && previous.isNotEmpty && previous != next) {
      await _delete(previous);
    }
  }

  /// The draft was saved with [savedPath]: keep it, delete every other file
  /// this draft captured (e.g. a photo taken before switching to voice).
  Future<void> commit(String? savedPath) async {
    _settled = true;
    // Saved: an entry references it now, so the sweep keeps it anyway.
    if (savedPath != null && _pending.remove(savedPath)) _release(savedPath);
    await _deleteAllPending();
  }

  /// The draft was discarded: delete every file it captured. No-op after
  /// [commit].
  Future<void> discard() async {
    if (_settled) return;
    _settled = true;
    await _deleteAllPending();
  }

  Future<void> _deleteAllPending() async {
    final paths = _pending.toList();
    for (final path in paths) {
      await _delete(path);
    }
  }

  Future<void> _delete(String path) async {
    if (_pending.remove(path)) _release(path);
    final deleter = _deleter;
    if (deleter == null) return;
    try {
      await deleter(path);
    } catch (e) {
      debugPrint('DraftMediaTracker could not delete "$path": $e');
    }
  }
}
