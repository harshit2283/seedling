import 'dart:convert';
import 'dart:io';

import 'export_models.dart';
import 'markdown_format.dart';
import 'safe_zip.dart';

/// Which kind of archive an import came from.
enum JournalImportSource { seedlingMarkdown, dayOne }

/// A parsed third-party / Markdown archive, ready for
/// `BackupRestoreService.preview` and `restore` (merge mode).
///
/// Entry maps use the same keys as Seedling's own backup JSON. Media is
/// extracted to [stagingDirectory] (bounded, one file at a time) and listed
/// in `backup.mediaFilePaths`; the caller deletes the directory afterwards.
class JournalImport {
  final JournalImportSource source;
  final LoadedEncryptedBackup backup;
  final String stagingDirectory;

  /// Files/entries that could not be represented (no date, empty, videos…).
  final int skipped;

  const JournalImport({
    required this.source,
    required this.backup,
    required this.stagingDirectory,
    required this.skipped,
  });
}

/// Opens [zipPath], detects its format and parses it. Synchronous I/O and
/// CPU work: run inside `Isolate.run`.
///
/// The ZIP is validated (entry count, declared sizes, zip-slip names)
/// before anything is inflated, and every read is bounded by
/// [SafeZipLimits.imports]. Never writes outside [stagingDirectory].
JournalImport readJournalArchive(String zipPath, String stagingDirectory) {
  final reader = SafeZipReader.fromFile(zipPath);
  try {
    Directory(stagingDirectory).createSync(recursive: true);
    final dayOneJournals = _findDayOneJournals(reader);
    if (dayOneJournals.isNotEmpty) {
      final dayOne = _readDayOne(reader, dayOneJournals, stagingDirectory);
      if (dayOne != null) return dayOne;
    }
    if (reader.files.any((e) => e.name.toLowerCase().endsWith('.md'))) {
      return _readSeedlingMarkdown(reader, stagingDirectory);
    }
    throw const FormatException(
      'This ZIP is not a Day One JSON export or a Markdown export',
    );
  } finally {
    reader.close();
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Stager {
  _Stager(this.reader, this.dir);
  final SafeZipReader reader;
  final String dir;
  final Map<String, String> staged = {};
  var _counter = 0;

  /// Extracts [entry] once and returns its key (the archive path).
  String? stage(SafeZipEntry? entry) {
    if (entry == null || entry.isDirectory) return null;
    if (staged.containsKey(entry.name)) return entry.name;
    final dot = entry.name.lastIndexOf('.');
    final ext = dot > entry.name.lastIndexOf('/') && dot >= 0
        ? entry.name.substring(dot + 1)
        : '';
    final safeExt = RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(ext) ? ext : 'bin';
    // Generated name: archive names never become file-system paths.
    final target = '$dir/m${_counter++}.$safeExt';
    reader.extractTo(entry, target);
    staged[entry.name] = target;
    return entry.name;
  }
}

String _isoUtc(DateTime value) => value.toUtc().toIso8601String();

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

LoadedEncryptedBackup _toBackup(
  List<Map<String, dynamic>> entries,
  _Stager stager,
  List<String> warnings,
) {
  return LoadedEncryptedBackup(
    preview: EncryptedBackupPreview(
      entryCount: entries.length,
      mediaCount: stager.staged.length,
      version: 1,
    ),
    entries: entries,
    mediaFiles: const {},
    mediaFilePaths: Map.unmodifiable(stager.staged),
    warnings: warnings,
  );
}

// ---------------------------------------------------------------------------
// Seedling Markdown (round-trip of exportToMarkdown; tolerant of Obsidian)
// ---------------------------------------------------------------------------

const _entryTypes = {
  'line',
  'photo',
  'voice',
  'object',
  'fragment',
  'ritual',
  'release',
};

JournalImport _readSeedlingMarkdown(SafeZipReader reader, String staging) {
  final stager = _Stager(reader, staging);
  final entries = <Map<String, dynamic>>[];
  var skipped = 0;

  final markdownFiles = reader.files
      .where((e) => e.name.toLowerCase().endsWith('.md'))
      .where((e) => e.name != MarkdownFormat.indexFile)
      .where((e) => !e.name.split('/').any((s) => s.startsWith('.')))
      .toList();

  for (final file in markdownFiles) {
    final Map<String, dynamic>? map;
    try {
      map = parseSeedlingMarkdown(
        utf8.decode(reader.readBytes(file), allowMalformed: true),
        archivePath: file.name,
        mediaExists: (path) => reader.find(path) != null,
      );
    } on UnsafeArchiveException {
      rethrow;
    } on FormatException {
      skipped++;
      continue;
    }
    if (map == null) {
      skipped++;
      continue;
    }
    final media = map['mediaPath'] as String?;
    if (media != null) stager.stage(reader.find(media));
    entries.add(map);
  }

  return JournalImport(
    source: JournalImportSource.seedlingMarkdown,
    backup: _toBackup(entries, stager, const []),
    stagingDirectory: staging,
    skipped: skipped,
  );
}

/// Parses one memory file. Returns null when it has no usable `date`.
///
/// [archivePath] locates the file so relative media links resolve;
/// [mediaExists] says whether a resolved archive path is present.
Map<String, dynamic>? parseSeedlingMarkdown(
  String source, {
  required String archivePath,
  required bool Function(String archivePath) mediaExists,
}) {
  final parsed = parseFrontMatter(source);
  final f = parsed.fields;
  final createdAt = DateTime.tryParse('${f[MarkdownFormat.keyDate] ?? ''}');
  if (createdAt == null) return null;

  var type = '${f[MarkdownFormat.keyType] ?? 'line'}'.toLowerCase();
  if (!_entryTypes.contains(type)) type = 'line';
  final title = _nonEmpty(f[MarkdownFormat.keyTitle]);

  // Media: front matter (archive-root relative), else first body link.
  String? mediaPath;
  final declared = _nonEmpty(f[MarkdownFormat.keyMedia]);
  if (declared != null) {
    final resolved = resolveArchiveLink('x', declared);
    if (resolved != null && mediaExists(resolved)) mediaPath = resolved;
  }
  final linkPattern = RegExp(r'^!?\[[^\]]*\]\(([^)\s]+)\)\s*$');

  var lines = parsed.body.replaceAll('\r\n', '\n').split('\n');
  String? bodyLinkTarget;
  for (final line in lines) {
    final m = linkPattern.firstMatch(line.trim());
    if (m == null) continue;
    final target = resolveArchiveLink(archivePath, Uri.decodeFull(m.group(1)!));
    if (target != null && target.startsWith('${MarkdownFormat.mediaDir}/')) {
      bodyLinkTarget ??= target;
    }
  }
  if (mediaPath == null &&
      bodyLinkTarget != null &&
      mediaExists(bodyLinkTarget)) {
    mediaPath = bodyLinkTarget;
  }

  // Strip what the exporter added around the user's text.
  final sealed = f[MarkdownFormat.keySealed] == true;
  lines = _dropLeadingBlank(lines);
  if (sealed &&
      lines.isNotEmpty &&
      lines.first.startsWith(MarkdownFormat.sealedNotePrefix)) {
    lines = _dropLeadingBlank(lines.sublist(1));
  }
  if (title != null && lines.isNotEmpty && lines.first.trim() == '# $title') {
    lines = _dropLeadingBlank(lines.sublist(1));
  }
  var body = lines.join('\n');

  String? transcription;
  if (type == 'voice') {
    final marker = '\n${MarkdownFormat.transcriptionHeading}\n';
    final padded = '\n$body';
    final at = padded.lastIndexOf(marker);
    if (at >= 0) {
      transcription = _nonEmpty(padded.substring(at + marker.length));
      body = padded.substring(0, at);
    }
  }
  if (mediaPath != null) {
    final kept = <String>[];
    var removed = false;
    for (final line in body.split('\n').reversed) {
      final m = linkPattern.firstMatch(line.trim());
      if (!removed && m != null) {
        final target = resolveArchiveLink(
          archivePath,
          Uri.decodeFull(m.group(1)!),
        );
        if (target == mediaPath) {
          removed = true;
          continue;
        }
      }
      kept.add(line);
    }
    body = kept.reversed.join('\n');
  }

  if (mediaPath == null && (type == 'photo' || type == 'voice')) {
    // The media did not travel with the file: keep the words.
    type = 'line';
  }

  final tagsField = f[MarkdownFormat.keyTags];
  final tags = tagsField is List
      ? tagsField
            .map((t) => '$t'.trim().replaceAll(',', ' '))
            .where((t) => t.isNotEmpty && t != 'null')
            .join(',')
      : _nonEmpty(tagsField);

  final unlock = DateTime.tryParse(
    '${f[MarkdownFormat.keyCapsuleUnlockDate] ?? ''}',
  );
  final modified = DateTime.tryParse('${f[MarkdownFormat.keyModified] ?? ''}');

  return <String, dynamic>{
    'type': type,
    'createdAt': _isoUtc(createdAt),
    'modifiedAt': modified == null ? null : _isoUtc(modified),
    'text': _nonEmpty(body),
    'title': title,
    'context': _nonEmpty(f[MarkdownFormat.keyContext]),
    'mood': _nonEmpty(f[MarkdownFormat.keyMood]),
    'tags': (tags == null || tags.isEmpty) ? null : tags,
    'detectedTheme': _nonEmpty(f[MarkdownFormat.keyTheme]),
    'mediaPath': mediaPath,
    'isReleased': f[MarkdownFormat.keyReleased] == true || type == 'release',
    'capsuleUnlockDate': unlock == null ? null : _isoUtc(unlock),
    'transcription': transcription,
    'syncUUID': _nonEmpty(f[MarkdownFormat.keySyncUUID]),
  };
}

List<String> _dropLeadingBlank(List<String> lines) {
  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  return lines.sublist(i);
}

// ---------------------------------------------------------------------------
// Day One JSON export
// ---------------------------------------------------------------------------

/// Day One's "JSON" export: one `<Journal>.json` per journal at the root
/// (`{"metadata":…, "entries":[…]}`), media in `photos/<md5>.<ext>` and
/// `audios/<md5>.<ext>`.
List<SafeZipEntry> _findDayOneJournals(SafeZipReader reader) {
  final result = <SafeZipEntry>[];
  for (final entry in reader.files) {
    final name = entry.name;
    final segments = name.split('/');
    // Root, or one wrapping folder (some unzip/re-zip tools add one).
    if (segments.length > 2 || !name.toLowerCase().endsWith('.json')) {
      continue;
    }
    if (segments.any((s) => s.startsWith('.') || s == '__MACOSX')) continue;
    if (name == 'entries.json' || name == 'manifest.json') continue;
    result.add(entry);
  }
  return result;
}

JournalImport? _readDayOne(
  SafeZipReader reader,
  List<SafeZipEntry> journals,
  String staging,
) {
  final stager = _Stager(reader, staging);
  // md5 -> archive entry, for photos/ and audios/ folders anywhere.
  final photosByMd5 = <String, SafeZipEntry>{};
  final audiosByMd5 = <String, SafeZipEntry>{};
  for (final e in reader.files) {
    final segments = e.name.split('/');
    if (segments.length < 2) continue;
    final folder = segments[segments.length - 2].toLowerCase();
    final file = segments.last;
    final dot = file.lastIndexOf('.');
    final stem = (dot > 0 ? file.substring(0, dot) : file).toLowerCase();
    if (folder == 'photos') photosByMd5[stem] = e;
    if (folder == 'audios') audiosByMd5[stem] = e;
  }

  final entries = <Map<String, dynamic>>[];
  final warnings = <String>{};
  var skipped = 0;
  var foundJournal = false;

  for (final journal in journals) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(reader.readBytes(journal)));
    } on UnsafeArchiveException {
      rethrow;
    } on FormatException {
      continue;
    }
    if (decoded is! Map || decoded['entries'] is! List) continue;
    foundJournal = true;
    for (final raw in decoded['entries'] as List) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      final mapped = mapDayOneEntry(
        raw.cast<String, dynamic>(),
        photoFor: (md5) => stager.stage(photosByMd5[md5.toLowerCase()]),
        audioFor: (md5) => stager.stage(audiosByMd5[md5.toLowerCase()]),
        onWarning: warnings.add,
      );
      if (mapped.isEmpty) {
        skipped++;
      } else {
        entries.addAll(mapped);
      }
    }
  }
  if (!foundJournal) return null;

  return JournalImport(
    source: JournalImportSource.dayOne,
    backup: _toBackup(entries, stager, warnings.toList()),
    stagingDirectory: staging,
    skipped: skipped,
  );
}

final _dayOneMoment = RegExp(r'!\[[^\]]*\]\(dayone-moment:[^)]*\)');
final _markdownEscape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>~<])');

/// Turns Day One's markdown-escaped text into plain text: drops embedded
/// `dayone-moment:` media references and un-escapes `\.` `\-` `\!` etc.
String cleanDayOneText(String text) {
  final withoutMoments = text.replaceAll(_dayOneMoment, '');
  final unescaped = withoutMoments.replaceAllMapped(
    _markdownEscape,
    (m) => m.group(1)!,
  );
  return unescaped
      .split('\n')
      .map((l) => l.trimRight())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Maps one Day One entry to Seedling entry maps.
///
/// Seedling holds one media file per memory, so:
/// * one photo → a photo memory carrying the text;
/// * one voice recording (no photos) → a voice memory carrying the text;
/// * no media → a line memory;
/// * several media → the first photo (else first recording) carries the
///   text and every further photo/recording becomes its own memory, one
///   second apart (keeps order and makes re-imports dedupe), titled
///   "<title> · 2 of 3" so they read as one moment.
/// A leading `# heading` becomes the title. Tags are kept, `starred`
/// becomes a "starred" tag and the place name goes into `context`.
/// Videos/PDFs are not supported and only produce a warning.
List<Map<String, dynamic>> mapDayOneEntry(
  Map<String, dynamic> raw, {
  required String? Function(String md5) photoFor,
  required String? Function(String md5) audioFor,
  void Function(String warning)? onWarning,
}) {
  final createdAt = DateTime.tryParse('${raw['creationDate'] ?? ''}');
  if (createdAt == null) return const [];
  final modified = DateTime.tryParse('${raw['modifiedDate'] ?? ''}');

  var text = cleanDayOneText('${raw['text'] ?? ''}');
  String? title;
  final heading = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(text.split('\n').first);
  if (heading != null) {
    title = heading.group(1)!.trim();
    text = text.split('\n').skip(1).join('\n').trim();
  }

  final tags = <String>[
    for (final t in (raw['tags'] as List?) ?? const [])
      if ('$t'.trim().isNotEmpty) '$t'.trim().replaceAll(',', ' '),
    if (raw['starred'] == true) 'starred',
  ];

  final location = raw['location'];
  String? context;
  if (location is Map) {
    final parts = <String>[];
    for (final key in ['placeName', 'localityName', 'country']) {
      final v = _nonEmpty(location[key]);
      if (v != null && !parts.contains(v)) parts.add(v);
    }
    if (parts.isNotEmpty) context = parts.join(', ');
  }

  List<Map<String, dynamic>> sorted(Object? list) {
    final items = <Map<String, dynamic>>[
      for (final m in (list as List?) ?? const [])
        if (m is Map) m.cast<String, dynamic>(),
    ];
    items.sort(
      (a, b) => ((a['orderInEntry'] as num?) ?? 0).compareTo(
        (b['orderInEntry'] as num?) ?? 0,
      ),
    );
    return items;
  }

  final media = <({String type, String path})>[];
  var missing = 0;
  for (final p in sorted(raw['photos'])) {
    final path = _nonEmpty(p['md5']) == null ? null : photoFor(p['md5']);
    if (path == null) {
      missing++;
    } else {
      media.add((type: 'photo', path: path));
    }
  }
  for (final a in sorted(raw['audios'])) {
    final path = _nonEmpty(a['md5']) == null ? null : audioFor(a['md5']);
    if (path == null) {
      missing++;
    } else {
      media.add((type: 'voice', path: path));
    }
  }
  if (missing > 0) onWarning?.call('missing_media');
  if (((raw['videos'] as List?)?.isNotEmpty ?? false) ||
      ((raw['pdfAttachments'] as List?)?.isNotEmpty ?? false)) {
    onWarning?.call('unsupported_media');
  }

  if (media.isEmpty && text.isEmpty && title == null) return const [];

  Map<String, dynamic> base(DateTime at) => <String, dynamic>{
    'createdAt': _isoUtc(at),
    'modifiedAt': modified == null ? null : _isoUtc(modified),
    'tags': tags.isEmpty ? null : tags.join(','),
    'context': context,
  };

  if (media.isEmpty) {
    return [
      {
        ...base(createdAt),
        'type': 'line',
        'text': _nonEmpty(text),
        'title': title,
      },
    ];
  }

  final total = media.length;
  return [
    for (var i = 0; i < total; i++)
      {
        ...base(createdAt.add(Duration(seconds: i))),
        'type': media[i].type,
        'mediaPath': media[i].path,
        'text': i == 0 ? _nonEmpty(text) : null,
        'title': total == 1 || i == 0
            ? title
            : '${title ?? 'Day One'} · ${i + 1} of $total',
      },
  ];
}
