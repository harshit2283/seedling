import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// One redacted error record.
@immutable
class DiagnosticsEntry {
  final DateTime at;
  final String? context;
  final String type;
  final String message;
  final List<String> frames;

  const DiagnosticsEntry({
    required this.at,
    required this.context,
    required this.type,
    required this.message,
    this.frames = const [],
  });

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    if (context != null) 'context': context,
    'type': type,
    'message': message,
    if (frames.isNotEmpty) 'frames': frames,
  };

  static DiagnosticsEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (at == null) return null;
    return DiagnosticsEntry(
      at: at,
      context: json['context'] as String?,
      type: json['type'] as String? ?? 'Object',
      message: json['message'] as String? ?? '',
      frames: (json['frames'] as List?)?.whereType<String>().toList() ?? [],
    );
  }
}

/// Local, on-device, rotating error log.
///
/// Nothing here ever leaves the phone on its own: the log is only shared when
/// the person taps "Share diagnostics" in Settings > About. Entries are
/// redacted before they are stored: quoted strings (where user content and
/// file names usually appear), absolute paths, URIs and email addresses are
/// replaced, messages are truncated, and only the top few stack frames
/// (code locations, not data) are kept.
class DiagnosticsLog {
  static const int maxEntries = 200;
  static const int _maxMessageLength = 200;
  static const int _maxFrames = 5;
  static const String fileName = 'error_log.jsonl';

  /// App-wide log; set once at startup. Null in tests and before init.
  static DiagnosticsLog? instance;

  final File _file;
  final List<DiagnosticsEntry> _entries = [];
  Future<void> _pendingWrite = Future.value();

  DiagnosticsLog._(this._file);

  /// Opens (and loads) the log in [directory], or the app support directory.
  static Future<DiagnosticsLog> open({Directory? directory}) async {
    final dir =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/diagnostics',
        );
    if (!await dir.exists()) await dir.create(recursive: true);
    final log = DiagnosticsLog._(File('${dir.path}/$fileName'));
    await log._load();
    return log;
  }

  List<DiagnosticsEntry> get entries => List.unmodifiable(_entries);

  Future<void> _load() async {
    try {
      if (!await _file.exists()) return;
      final lines = await _file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final entry = DiagnosticsEntry.fromJson(jsonDecode(line));
          if (entry != null) _entries.add(entry);
        } on FormatException {
          // Skip a corrupt line rather than losing the whole log.
        }
      }
      _trim();
    } catch (_) {
      _entries.clear();
    }
  }

  /// Records a redacted copy of [error]. Never throws.
  void record(Object error, {StackTrace? stack, String? context}) {
    _entries.add(
      DiagnosticsEntry(
        at: DateTime.now(),
        context: context == null ? null : redact(context),
        type: error.runtimeType.toString(),
        message: redact(describe(error)),
        frames: _topFrames(stack),
      ),
    );
    _trim();
    _scheduleWrite();
  }

  /// Flushes pending writes (for tests and before sharing).
  Future<void> flush() => _pendingWrite;

  Future<void> clear() async {
    _entries.clear();
    _scheduleWrite();
    await flush();
  }

  /// Plain-text report the person can review in the share sheet.
  String exportText({String? appVersion}) {
    final buffer = StringBuffer()
      ..writeln('Seedling diagnostics')
      ..writeln(
        'Recent errors on this device. No memory text; paths and quoted '
        'values are removed.',
      );
    if (appVersion != null) buffer.writeln('Version: $appVersion');
    buffer.writeln('Entries: ${_entries.length}');
    for (final entry in _entries) {
      buffer
        ..writeln()
        ..writeln(
          '${entry.at.toUtc().toIso8601String()}'
          '${entry.context == null ? '' : ' [${entry.context}]'} '
          '${entry.type}: ${entry.message}',
        );
      for (final frame in entry.frames) {
        buffer.writeln('    $frame');
      }
    }
    return buffer.toString();
  }

  void _trim() {
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  void _scheduleWrite() {
    final snapshot = _entries.map((e) => jsonEncode(e.toJson())).join('\n');
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _file.writeAsString(snapshot, flush: true);
      } catch (_) {
        // Diagnostics are best effort.
      }
    });
  }

  /// Short description of [error] without the raw input some exceptions
  /// embed (FormatException.toString() includes the source being parsed).
  @visibleForTesting
  static String describe(Object error) {
    if (error is FormatException) return 'FormatException: ${error.message}';
    if (error is FileSystemException) {
      return 'FileSystemException: ${error.message}'
          '${error.osError == null ? '' : ' (${error.osError!.message})'}';
    }
    return error.toString();
  }

  static final _quoted = RegExp(r'''"[^"]*"|'[^']*'|`[^`]*`''');
  static final _uri = RegExp(r'\b[a-zA-Z][a-zA-Z0-9+.-]*://\S+');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _unixPath = RegExp(r'(?:~|\.{1,2})?(?:/[^\s/:,;)\]]+){2,}/?');
  static final _windowsPath = RegExp(r'[A-Za-z]:\\[^\s,;)\]]+');

  /// Removes content that could identify the person or their memories.
  @visibleForTesting
  static String redact(String input) {
    var out = input
        .replaceAll(_quoted, '<redacted>')
        .replaceAll(_uri, '<uri>')
        .replaceAll(_email, '<email>')
        .replaceAll(_windowsPath, '<path>')
        .replaceAll(_unixPath, '<path>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (out.length > _maxMessageLength) {
      out = '${out.substring(0, _maxMessageLength)}…';
    }
    return out;
  }

  static List<String> _topFrames(StackTrace? stack) {
    if (stack == null) return const [];
    return stack
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        // Keep only code locations from Dart packages / SDK; drop anything
        // that could carry an absolute path on the device.
        .map(
          (l) => l
              .replaceAll(RegExp(r'file://\S+'), '<file>')
              .replaceAll(_unixPath, '<path>'),
        )
        .take(_maxFrames)
        .toList();
  }
}

/// The app's diagnostics log, or null when it could not be opened.
final diagnosticsLogProvider = Provider<DiagnosticsLog?>(
  (ref) => DiagnosticsLog.instance,
);
