import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../../../data/models/entry.dart';
import 'markdown_format.dart';

/// Plain, isolate-safe snapshot of one memory for the Markdown export.
class MarkdownExportItem {
  final String type;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? title;
  final String? text;
  final String? transcription;
  final List<String> tags;
  final String? theme;
  final String? mood;
  final String? context;
  final DateTime? capsuleUnlockDate;
  final bool isSealed;
  final bool isReleased;
  final String? syncUUID;

  /// Absolute path of the media file on disk (already resolved), if any.
  final String? mediaSourcePath;

  /// File name to use inside `media/<folder>/`.
  final String? mediaFileName;

  const MarkdownExportItem({
    required this.type,
    required this.createdAt,
    this.modifiedAt,
    this.title,
    this.text,
    this.transcription,
    this.tags = const [],
    this.theme,
    this.mood,
    this.context,
    this.capsuleUnlockDate,
    this.isSealed = false,
    this.isReleased = false,
    this.syncUUID,
    this.mediaSourcePath,
    this.mediaFileName,
  });

  /// Snapshot of [entry]. [resolvedMediaPath] is the media file's current
  /// location (see `FileStorageService.resolveMediaPath`), or null when the
  /// file is missing — the memory is still exported, without the link.
  factory MarkdownExportItem.fromEntry(
    Entry entry, {
    String? resolvedMediaPath,
    DateTime? now,
  }) {
    final unlock = entry.capsuleUnlockDate;
    final sealed =
        unlock != null &&
        (now ?? DateTime.now()).toUtc().isBefore(unlock.toUtc());
    return MarkdownExportItem(
      type: entry.type.name,
      createdAt: entry.createdAt,
      modifiedAt: entry.modifiedAt,
      title: entry.title,
      text: entry.text,
      transcription: entry.transcription,
      tags: (entry.tags ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      theme: entry.detectedTheme,
      mood: entry.mood,
      context: entry.context,
      capsuleUnlockDate: unlock,
      isSealed: sealed,
      isReleased: entry.isReleased,
      syncUUID: entry.syncUUID,
      mediaSourcePath: resolvedMediaPath,
      mediaFileName: resolvedMediaPath?.replaceAll('\\', '/').split('/').last,
    );
  }
}

/// One file of the export: either text content or a media file on disk.
class MarkdownExportFile {
  final String path;
  final String? content;
  final String? sourcePath;

  const MarkdownExportFile.text(this.path, String this.content)
    : sourcePath = null;
  const MarkdownExportFile.media(this.path, String this.sourcePath)
    : content = null;
}

/// The complete file list of a Markdown export.
class MarkdownExportPlan {
  final List<MarkdownExportFile> files;
  final int memoryCount;
  final int mediaCount;

  const MarkdownExportPlan(this.files, this.memoryCount, this.mediaCount);
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _two(int v) => v.toString().padLeft(2, '0');

String _mediaFolder(String type) => switch (type) {
  'voice' => 'voices',
  'object' => 'objects',
  _ => 'photos',
};

/// ASCII slug of at most [max] characters; empty when nothing usable.
String slugify(String? input, {int max = 40}) {
  if (input == null) return '';
  final lowered = input.toLowerCase();
  final buffer = StringBuffer();
  var lastDash = true;
  for (final rune in lowered.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buffer.write(ch);
      lastDash = false;
    } else if (!lastDash) {
      buffer.write('-');
      lastDash = true;
    }
    if (buffer.length >= max) break;
  }
  var slug = buffer.toString();
  while (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }
  return slug;
}

String _firstLine(String? text) {
  if (text == null) return '';
  final line = text.trim().split('\n').first.trim();
  return line.length > 60 ? '${line.substring(0, 57)}...' : line;
}

String _escapeLinkLabel(String label) =>
    label.replaceAll(r'\', r'\\').replaceAll('[', r'\[').replaceAll(']', r'\]');

/// Builds the export file list. Pure: no I/O.
MarkdownExportPlan buildMarkdownExport(
  List<MarkdownExportItem> items, {
  required DateTime exportedAt,
}) {
  final sorted = [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final usedPaths = <String>{};
  final usedMedia = <String>{};
  final files = <MarkdownExportFile>[];
  final indexEntries = <_IndexLine>[];
  var mediaCount = 0;

  String unique(String base, String ext, Set<String> used) {
    var candidate = '$base$ext';
    var n = 2;
    while (!used.add(candidate)) {
      candidate = '$base-$n$ext';
      n++;
    }
    return candidate;
  }

  for (final item in sorted) {
    final local = item.createdAt.toLocal();
    final stamp =
        '${local.year}-${_two(local.month)}-${_two(local.day)}-'
        '${_two(local.hour)}${_two(local.minute)}';

    final String dir;
    final String slug;
    if (item.isSealed) {
      dir = MarkdownFormat.capsulesDir;
      final opens = item.capsuleUnlockDate!.toLocal();
      // No content in the file name: browsing the folder must not spoil it.
      slug =
          'capsule-opens-${opens.year}-${_two(opens.month)}-${_two(opens.day)}';
    } else {
      dir = '${MarkdownFormat.memoriesDir}/${local.year}/${_two(local.month)}';
      final fromTitle = slugify(item.title);
      slug = fromTitle.isNotEmpty
          ? fromTitle
          : (slugify(item.text).isNotEmpty ? slugify(item.text) : item.type);
    }
    final mdPath = unique('$dir/$stamp-$slug', '.md', usedPaths);
    final depth = mdPath.split('/').length - 1;
    final up = List.filled(depth, '..').join('/');

    String? mediaArchivePath;
    final source = item.mediaSourcePath;
    if (source != null && item.mediaFileName != null) {
      final name = item.mediaFileName!;
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      mediaArchivePath = unique(
        '${MarkdownFormat.mediaDir}/${_mediaFolder(item.type)}/$base',
        ext,
        usedMedia,
      );
      files.add(MarkdownExportFile.media(mediaArchivePath, source));
      mediaCount++;
    }

    files.add(
      MarkdownExportFile.text(
        mdPath,
        _renderMemory(item, mediaArchivePath: mediaArchivePath, up: up),
      ),
    );
    indexEntries.add(_IndexLine(item, mdPath));
  }

  files.insert(
    0,
    MarkdownExportFile.text(
      MarkdownFormat.indexFile,
      _renderIndex(
        indexEntries,
        exportedAt: exportedAt,
        mediaCount: mediaCount,
      ),
    ),
  );
  return MarkdownExportPlan(files, sorted.length, mediaCount);
}

String _renderMemory(
  MarkdownExportItem item, {
  required String? mediaArchivePath,
  required String up,
}) {
  final fields = <String, Object?>{
    MarkdownFormat.keyDate: bare(isoWithOffset(item.createdAt)),
    MarkdownFormat.keyType: bare(item.type),
    MarkdownFormat.keyTitle: item.title,
    MarkdownFormat.keyTags: item.tags,
    MarkdownFormat.keyTheme: item.theme == null ? null : bare(item.theme!),
    MarkdownFormat.keyMood: item.mood,
    MarkdownFormat.keyContext: item.context,
    MarkdownFormat.keyCapsuleUnlockDate: item.capsuleUnlockDate == null
        ? null
        : bare(isoWithOffset(item.capsuleUnlockDate!)),
    MarkdownFormat.keySealed: item.isSealed ? true : null,
    MarkdownFormat.keyReleased: item.isReleased ? true : null,
    MarkdownFormat.keyMedia: mediaArchivePath,
    MarkdownFormat.keyModified: item.modifiedAt == null
        ? null
        : bare(isoWithOffset(item.modifiedAt!)),
    MarkdownFormat.keySyncUUID: item.syncUUID,
  };

  final body = StringBuffer();
  if (item.isSealed) {
    final opens = item.capsuleUnlockDate!.toLocal();
    body.writeln(
      '${MarkdownFormat.sealedNotePrefix} In Seedling this capsule stays '
      'closed until ${opens.day} ${_monthNames[opens.month - 1]} '
      '${opens.year}. It is included here because it is yours.',
    );
    body.writeln();
  }
  final title = item.title?.trim();
  if (title != null && title.isNotEmpty) {
    body.writeln('# $title');
    body.writeln();
  }
  final text = item.text?.trim();
  if (text != null && text.isNotEmpty) {
    body.writeln(text);
    body.writeln();
  }
  if (mediaArchivePath != null) {
    final link = Uri.encodeFull('$up/$mediaArchivePath');
    if (item.type == 'voice') {
      body.writeln('[Voice memo]($link)');
    } else {
      body.writeln('![${item.type == 'object' ? 'Object' : 'Photo'}]($link)');
    }
    body.writeln();
  }
  final transcription = item.transcription?.trim();
  if (transcription != null && transcription.isNotEmpty) {
    body.writeln(MarkdownFormat.transcriptionHeading);
    body.writeln();
    body.writeln(transcription);
    body.writeln();
  }
  return '${writeFrontMatter(fields)}\n${body.toString().trimRight()}\n';
}

class _IndexLine {
  final MarkdownExportItem item;
  final String path;
  const _IndexLine(this.item, this.path);
}

String _renderIndex(
  List<_IndexLine> lines, {
  required DateTime exportedAt,
  required int mediaCount,
}) {
  final b = StringBuffer();
  final when = exportedAt.toLocal();
  b.writeln(
    writeFrontMatter({
      MarkdownFormat.keyFormat: bare(MarkdownFormat.formatName),
      'version': MarkdownFormat.formatVersion,
      'exported': bare(isoWithOffset(exportedAt)),
      'memories': lines.length,
      'mediaFiles': mediaCount,
    }),
  );
  b.writeln('# Seedling memories');
  b.writeln();
  b.writeln(
    'Exported ${when.day} ${_monthNames[when.month - 1]} ${when.year} · '
    '${lines.length} ${lines.length == 1 ? 'memory' : 'memories'} · '
    '$mediaCount media ${mediaCount == 1 ? 'file' : 'files'}',
  );
  b.writeln();
  b.writeln(
    'Each memory is a plain Markdown file with YAML front matter (date, '
    'type, title, tags, theme, capsule date, syncUUID). Photos and voice '
    'memos live in `media/` and are linked from their memory. Open this '
    'folder in any Markdown editor or as an Obsidian vault, or import the '
    'ZIP back into Seedling.',
  );

  final open = lines.where((l) => !l.item.isSealed).toList();
  final sealed = lines.where((l) => l.item.isSealed).toList();

  int? year;
  int? month;
  for (final line in open) {
    final local = line.item.createdAt.toLocal();
    if (local.year != year) {
      year = local.year;
      month = null;
      b.writeln();
      b.writeln('## $year');
    }
    if (local.month != month) {
      month = local.month;
      b.writeln();
      b.writeln('### ${_monthNames[local.month - 1]}');
      b.writeln();
    }
    final label = _firstLine(line.item.title).isNotEmpty
        ? _firstLine(line.item.title)
        : (_firstLine(line.item.text).isNotEmpty
              ? _firstLine(line.item.text)
              : _typeLabel(line.item.type));
    b.writeln(
      '- [${local.day} ${_monthNames[local.month - 1].substring(0, 3)} · '
      '${_escapeLinkLabel(label)}](${Uri.encodeFull(line.path)})',
    );
  }

  if (sealed.isNotEmpty) {
    b.writeln();
    b.writeln('## Sealed capsules');
    b.writeln();
    b.writeln(
      'These capsules were still sealed when you exported. Their content is '
      'included because it is yours; the links below do not reveal it.',
    );
    b.writeln();
    for (final line in sealed) {
      final opens = line.item.capsuleUnlockDate!.toLocal();
      b.writeln(
        '- [Opens ${opens.day} ${_monthNames[opens.month - 1]} ${opens.year}]'
        '(${Uri.encodeFull(line.path)})',
      );
    }
  }
  return b.toString();
}

String _typeLabel(String type) => switch (type) {
  'photo' => 'Photo',
  'voice' => 'Voice memo',
  'object' => 'Object',
  'fragment' => 'Fragment',
  'ritual' => 'Ritual',
  'release' => 'Released',
  _ => 'Memory',
};

/// Writes [plan] as a ZIP at [outputPath], streaming media from disk.
/// Synchronous file I/O: run inside `Isolate.run`.
void writeMarkdownExportZip(MarkdownExportPlan plan, String outputPath) {
  final encoder = ZipFileEncoder()..create(outputPath);
  try {
    for (final file in plan.files) {
      final content = file.content;
      if (content != null) {
        encoder.addArchiveFile(
          ArchiveFile.bytes(file.path, utf8.encode(content)),
        );
        continue;
      }
      final source = File(file.sourcePath!);
      if (source.existsSync()) encoder.addFileSync(source, file.path);
    }
  } finally {
    encoder.closeSync();
  }
}
