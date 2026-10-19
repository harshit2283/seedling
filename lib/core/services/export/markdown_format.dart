import 'dart:convert';

/// Shared vocabulary of Seedling's open Markdown export: front-matter keys,
/// folder layout and the small YAML subset we write and read back.
///
/// Layout of an export ZIP:
/// ```
/// index.md                          table of contents + format notes
/// memories/<yyyy>/<mm>/<file>.md    one file per memory
/// capsules/<file>.md                capsules that were still sealed
/// media/photos|voices|objects/...   original media files
/// ```
/// Every memory file starts with YAML front matter (keys below), then the
/// body: an optional `# title`, the text, a relative link to the media file
/// and, for voice memos, a `## Transcription` section.
abstract final class MarkdownFormat {
  static const String formatName = 'seedling-markdown';
  static const int formatVersion = 1;

  static const String memoriesDir = 'memories';
  static const String capsulesDir = 'capsules';
  static const String mediaDir = 'media';
  static const String indexFile = 'index.md';

  static const String keyDate = 'date';
  static const String keyModified = 'modified';
  static const String keyType = 'type';
  static const String keyTitle = 'title';
  static const String keyTags = 'tags';
  static const String keyTheme = 'theme';
  static const String keyMood = 'mood';
  static const String keyContext = 'context';
  static const String keyCapsuleUnlockDate = 'capsuleUnlockDate';
  static const String keySealed = 'sealed';
  static const String keyReleased = 'released';
  static const String keyMedia = 'media';
  static const String keySyncUUID = 'syncUUID';
  static const String keyFormat = 'seedling';

  static const String transcriptionHeading = '## Transcription';
  static const String sealedNotePrefix = '> **Sealed capsule.**';
}

/// ISO-8601 with the local UTC offset (e.g. `2024-03-05T14:22:00+01:00`):
/// readable as local time, still unambiguous.
String isoWithOffset(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  String two(int v) => v.toString().padLeft(2, '0');
  // Milliseconds only when present, so re-imports match the exact instant.
  final ms = local.millisecond == 0
      ? ''
      : '.${local.millisecond.toString().padLeft(3, '0')}';
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$ms$sign$hh:$mm';
}

/// Writes a YAML front-matter block. Free text is emitted as double-quoted
/// JSON strings, which are valid YAML scalars, so no user text can break
/// out of its value. Null/empty values are omitted.
String writeFrontMatter(Map<String, Object?> fields) {
  final buffer = StringBuffer('---\n');
  fields.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    if (value is List && value.isEmpty) return;
    buffer.write('$key: ');
    if (value is bool || value is num) {
      buffer.write(value.toString());
    } else if (value is List) {
      buffer.write(jsonEncode(value.map((v) => v.toString()).toList()));
    } else if (value is _Bare) {
      buffer.write(value.value);
    } else {
      buffer.write(jsonEncode(value.toString()));
    }
    buffer.write('\n');
  });
  buffer.write('---\n');
  return buffer.toString();
}

/// Marks a value that is already a safe YAML plain scalar (dates, enums).
class _Bare {
  const _Bare(this.value);
  final String value;
}

/// Wraps a token that needs no quoting (only `[A-Za-z0-9:+._-]`).
Object bare(String value) =>
    RegExp(r'^[A-Za-z0-9:+._-]+$').hasMatch(value) ? _Bare(value) : value;

/// A parsed Markdown file: front matter fields + remaining body.
class ParsedMarkdown {
  final Map<String, Object?> fields;
  final String body;
  final bool hasFrontMatter;

  const ParsedMarkdown(this.fields, this.body, {required this.hasFrontMatter});
}

/// Parses the YAML front matter we write, plus the forms Obsidian rewrites
/// it into: single-quoted / plain scalars and block lists (`- item`).
/// Anything it does not understand is kept as a plain string.
ParsedMarkdown parseFrontMatter(String source) {
  var text = source.replaceAll('\r\n', '\n');
  if (text.startsWith('﻿')) text = text.substring(1);
  if (!text.startsWith('---\n')) {
    return ParsedMarkdown(const {}, text, hasFrontMatter: false);
  }
  final end = RegExp(r'^(---|\.\.\.)[ \t]*$', multiLine: true);
  final match = end.allMatches(text, 4).firstOrNull;
  if (match == null) {
    return ParsedMarkdown(const {}, text, hasFrontMatter: false);
  }
  final yaml = text.substring(4, match.start);
  var body = text.substring(match.end);
  if (body.startsWith('\n')) body = body.substring(1);

  final fields = <String, Object?>{};
  String? listKey;
  for (final rawLine in yaml.split('\n')) {
    if (rawLine.trim().isEmpty || rawLine.trimLeft().startsWith('#')) continue;
    final listItem = RegExp(r'^\s+-\s*(.*)$').firstMatch(rawLine);
    if (listItem != null && listKey != null) {
      final list = (fields[listKey] as List<Object?>?) ?? <Object?>[];
      list.add(_parseScalar(listItem.group(1)!));
      fields[listKey] = list;
      continue;
    }
    final kv = RegExp(
      r'^([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$',
    ).firstMatch(rawLine);
    if (kv == null) continue;
    final key = kv.group(1)!;
    final rawValue = kv.group(2)!.trim();
    if (rawValue.isEmpty) {
      listKey = key;
      fields[key] = null;
      continue;
    }
    listKey = null;
    fields[key] = _parseValue(rawValue);
  }
  return ParsedMarkdown(fields, body, hasFrontMatter: true);
}

Object? _parseValue(String raw) {
  if (raw.startsWith('[') && raw.endsWith(']')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } on FormatException {
      // Unquoted flow list, e.g. [a, b].
    }
    final inner = raw.substring(1, raw.length - 1).trim();
    if (inner.isEmpty) return <Object?>[];
    return inner.split(',').map((s) => _parseScalar(s.trim())).toList();
  }
  return _parseScalar(raw);
}

Object? _parseScalar(String raw) {
  if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
    try {
      return jsonDecode(raw) as String;
    } on FormatException {
      return raw.substring(1, raw.length - 1);
    }
  }
  if (raw.startsWith("'") && raw.endsWith("'") && raw.length >= 2) {
    return raw.substring(1, raw.length - 1).replaceAll("''", "'");
  }
  // Strip a trailing comment on plain scalars.
  final hash = raw.indexOf(' #');
  final value = hash >= 0 ? raw.substring(0, hash).trim() : raw;
  if (value == 'true') return true;
  if (value == 'false') return false;
  if (value == 'null' || value == '~') return null;
  return value;
}
