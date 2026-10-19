import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

/// Limits applied to an untrusted ZIP before anything is inflated.
class SafeZipLimits {
  /// Maximum number of entries (files + directories) in the central directory.
  final int maxEntries;

  /// Maximum sum of the declared uncompressed sizes of all entries.
  final int maxTotalBytes;

  /// Maximum declared uncompressed size of any single entry.
  final int maxEntryBytes;

  const SafeZipLimits({
    required this.maxEntries,
    required this.maxTotalBytes,
    required this.maxEntryBytes,
  });

  /// Limits for archives Seedling itself produced (backups, Markdown export)
  /// and for third-party journal exports such as Day One.
  static const imports = SafeZipLimits(
    maxEntries: 20000,
    maxTotalBytes: 2 * 1024 * 1024 * 1024,
    maxEntryBytes: 512 * 1024 * 1024,
  );
}

/// One entry of the central directory, as declared by the archive.
class SafeZipEntry {
  final String name;
  final int method;
  final int flags;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final bool isDirectory;
  final bool isSymlink;

  const SafeZipEntry({
    required this.name,
    required this.method,
    required this.flags,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.isDirectory,
    required this.isSymlink,
  });

  bool get isEncrypted => (flags & 0x1) != 0;
}

/// Thrown when an archive is malformed, unsafe or exceeds [SafeZipLimits].
class UnsafeArchiveException extends FormatException {
  const UnsafeArchiveException(super.message);
}

abstract class _ByteSource {
  int get length;
  Uint8List read(int offset, int length);
  void close();
}

class _MemorySource implements _ByteSource {
  _MemorySource(this._bytes);
  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Uint8List read(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > _bytes.length) {
      throw const UnsafeArchiveException('Archive is truncated');
    }
    return Uint8List.sublistView(_bytes, offset, offset + length);
  }

  @override
  void close() {}
}

class _FileSource implements _ByteSource {
  _FileSource(this._file) : length = _file.lengthSync();
  final RandomAccessFile _file;

  @override
  final int length;

  @override
  Uint8List read(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw const UnsafeArchiveException('Archive is truncated');
    }
    _file.setPositionSync(offset);
    final bytes = _file.readSync(count);
    if (bytes.length != count) {
      throw const UnsafeArchiveException('Archive is truncated');
    }
    return bytes;
  }

  @override
  void close() => _file.closeSync();
}

/// A defensive, synchronous ZIP reader for untrusted archives.
///
/// Unlike decoding with `package:archive` directly, it:
/// * parses the central directory itself and rejects the archive *before
///   inflating anything* when the entry count or declared sizes exceed the
///   [SafeZipLimits] (zip-bomb defence);
/// * enforces the declared size while inflating, so an entry that lies about
///   its size is cut off as soon as it overruns instead of exhausting memory;
/// * rejects zip-slip names (`..`, absolute paths, drive letters, NUL),
///   symlinks and encrypted entries;
/// * verifies CRC-32 of every entry read.
///
/// All I/O is synchronous: run it inside `Isolate.run`.
class SafeZipReader {
  SafeZipReader._(this._source, this.limits) {
    try {
      _entries = _readCentralDirectory();
    } catch (_) {
      _source.close();
      rethrow;
    }
  }

  /// Opens an in-memory archive.
  factory SafeZipReader.fromBytes(
    Uint8List bytes, {
    SafeZipLimits limits = SafeZipLimits.imports,
  }) => SafeZipReader._(_MemorySource(bytes), limits);

  /// Opens an archive on disk without loading it into memory.
  factory SafeZipReader.fromFile(
    String path, {
    SafeZipLimits limits = SafeZipLimits.imports,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('Archive file not found');
    }
    return SafeZipReader._(_FileSource(file.openSync()), limits);
  }

  final _ByteSource _source;
  final SafeZipLimits limits;
  late final List<SafeZipEntry> _entries;
  late final Map<String, SafeZipEntry> _byName = {
    for (final e in _entries) e.name: e,
  };

  static const int _chunkSize = 64 * 1024;

  /// All entries, in central-directory order.
  List<SafeZipEntry> get entries => List.unmodifiable(_entries);

  /// Regular (non-directory) file entries.
  Iterable<SafeZipEntry> get files => _entries.where((e) => !e.isDirectory);

  SafeZipEntry? find(String name) => _byName[name];

  /// Sum of declared uncompressed sizes.
  int get declaredTotalBytes =>
      _entries.fold(0, (sum, e) => sum + e.uncompressedSize);

  void close() => _source.close();

  /// Inflates [entry] into memory, bounded by its declared size.
  Uint8List readBytes(SafeZipEntry entry) {
    final builder = BytesBuilder(copy: false);
    _inflate(entry, builder.add);
    return builder.takeBytes();
  }

  /// Inflates [entry] into [destinationPath], bounded by its declared size.
  /// A partially written file is removed on failure.
  void extractTo(SafeZipEntry entry, String destinationPath) {
    final file = File(destinationPath);
    file.parent.createSync(recursive: true);
    final sink = file.openSync(mode: FileMode.writeOnly);
    var ok = false;
    try {
      _inflate(entry, sink.writeFromSync);
      ok = true;
    } finally {
      sink.closeSync();
      if (!ok && file.existsSync()) file.deleteSync();
    }
  }

  void _inflate(SafeZipEntry entry, void Function(List<int> chunk) emit) {
    if (entry.isDirectory) return;
    if (entry.isSymlink) {
      throw const UnsafeArchiveException('Symbolic links are not allowed');
    }
    if (entry.isEncrypted) {
      throw const UnsafeArchiveException('Encrypted archives are unsupported');
    }
    if (entry.method != 0 && entry.method != 8) {
      throw const UnsafeArchiveException('Unsupported compression method');
    }

    final header = _source.read(entry.localHeaderOffset, 30);
    final hv = ByteData.sublistView(header);
    if (hv.getUint32(0, Endian.little) != 0x04034b50) {
      throw const UnsafeArchiveException('Corrupt local file header');
    }
    final nameLen = hv.getUint16(26, Endian.little);
    final extraLen = hv.getUint16(28, Endian.little);
    final dataStart = entry.localHeaderOffset + 30 + nameLen + extraLen;
    if (dataStart + entry.compressedSize > _source.length) {
      throw const UnsafeArchiveException('Archive is truncated');
    }

    var produced = 0;
    var crc = 0;
    void accept(List<int> chunk) {
      if (chunk.isEmpty) return;
      produced += chunk.length;
      if (produced > entry.uncompressedSize) {
        throw const UnsafeArchiveException(
          'Archive entry is larger than declared',
        );
      }
      crc = getCrc32(chunk, crc);
      emit(chunk);
    }

    final filter = entry.method == 8
        ? RawZLibFilter.inflateFilter(raw: true)
        : null;
    var offset = 0;
    while (offset < entry.compressedSize) {
      final count = math.min(_chunkSize, entry.compressedSize - offset);
      final chunk = _source.read(dataStart + offset, count);
      offset += count;
      if (filter == null) {
        accept(chunk);
        continue;
      }
      filter.process(chunk, 0, chunk.length);
      List<int>? out;
      while ((out = filter.processed(flush: false)) != null) {
        accept(out!);
      }
    }
    if (filter != null) {
      List<int>? out;
      while ((out = filter.processed(end: true)) != null) {
        accept(out!);
      }
    }

    if (produced != entry.uncompressedSize) {
      throw const UnsafeArchiveException('Archive entry size mismatch');
    }
    if (crc != entry.crc32) {
      throw const UnsafeArchiveException('Archive entry checksum mismatch');
    }
  }

  List<SafeZipEntry> _readCentralDirectory() {
    final length = _source.length;
    if (length < 22) {
      throw const UnsafeArchiveException('Not a ZIP archive');
    }
    // End of central directory: last 22 bytes + up to 64 KiB comment.
    final tailLength = math.min(length, 22 + 0xFFFF);
    final tailStart = length - tailLength;
    final tail = _source.read(tailStart, tailLength);
    final tv = ByteData.sublistView(tail);
    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tv.getUint32(i, Endian.little) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      throw const UnsafeArchiveException('Not a ZIP archive');
    }

    var totalEntries = tv.getUint16(eocd + 10, Endian.little);
    var cdSize = tv.getUint32(eocd + 12, Endian.little);
    var cdOffset = tv.getUint32(eocd + 16, Endian.little);

    // ZIP64 end-of-central-directory locator sits right before the EOCD.
    if (totalEntries == 0xFFFF ||
        cdSize == 0xFFFFFFFF ||
        cdOffset == 0xFFFFFFFF) {
      final locatorPos = tailStart + eocd - 20;
      if (locatorPos < 0) {
        throw const UnsafeArchiveException('Corrupt ZIP64 archive');
      }
      final loc = ByteData.sublistView(_source.read(locatorPos, 20));
      if (loc.getUint32(0, Endian.little) != 0x07064b50) {
        throw const UnsafeArchiveException('Corrupt ZIP64 archive');
      }
      final z64Offset = loc.getUint64(8, Endian.little);
      final z64 = ByteData.sublistView(_source.read(z64Offset, 56));
      if (z64.getUint32(0, Endian.little) != 0x06064b50) {
        throw const UnsafeArchiveException('Corrupt ZIP64 archive');
      }
      totalEntries = z64.getUint64(32, Endian.little);
      cdSize = z64.getUint64(40, Endian.little);
      cdOffset = z64.getUint64(48, Endian.little);
    }

    if (totalEntries > limits.maxEntries) {
      throw const UnsafeArchiveException('Archive contains too many files');
    }
    if (cdOffset + cdSize > length) {
      throw const UnsafeArchiveException('Archive is truncated');
    }

    final cd = _source.read(cdOffset, cdSize);
    final cv = ByteData.sublistView(cd);
    final entries = <SafeZipEntry>[];
    final seen = <String>{};
    var pos = 0;
    var declaredTotal = 0;
    while (pos + 46 <= cd.length) {
      if (cv.getUint32(pos, Endian.little) != 0x02014b50) break;
      if (entries.length >= limits.maxEntries) {
        throw const UnsafeArchiveException('Archive contains too many files');
      }
      final versionMadeBy = cv.getUint16(pos + 4, Endian.little);
      final flags = cv.getUint16(pos + 8, Endian.little);
      final method = cv.getUint16(pos + 10, Endian.little);
      final crc = cv.getUint32(pos + 16, Endian.little);
      var compressed = cv.getUint32(pos + 20, Endian.little);
      var uncompressed = cv.getUint32(pos + 24, Endian.little);
      final nameLen = cv.getUint16(pos + 28, Endian.little);
      final extraLen = cv.getUint16(pos + 30, Endian.little);
      final commentLen = cv.getUint16(pos + 32, Endian.little);
      final externalAttrs = cv.getUint32(pos + 38, Endian.little);
      var localOffset = cv.getUint32(pos + 42, Endian.little);
      final end = pos + 46 + nameLen + extraLen + commentLen;
      if (end > cd.length) {
        throw const UnsafeArchiveException('Corrupt central directory');
      }
      final nameBytes = Uint8List.sublistView(cd, pos + 46, pos + 46 + nameLen);
      final name = _decodeName(nameBytes, utf8Flag: (flags & 0x800) != 0);

      // ZIP64 extended information extra field.
      if (uncompressed == 0xFFFFFFFF ||
          compressed == 0xFFFFFFFF ||
          localOffset == 0xFFFFFFFF) {
        var e = pos + 46 + nameLen;
        final extraEnd = e + extraLen;
        var found = false;
        while (e + 4 <= extraEnd) {
          final id = cv.getUint16(e, Endian.little);
          final size = cv.getUint16(e + 2, Endian.little);
          if (id == 0x0001) {
            var p = e + 4;
            final limit = math.min(e + 4 + size, extraEnd);
            if (uncompressed == 0xFFFFFFFF && p + 8 <= limit) {
              uncompressed = cv.getUint64(p, Endian.little);
              p += 8;
            }
            if (compressed == 0xFFFFFFFF && p + 8 <= limit) {
              compressed = cv.getUint64(p, Endian.little);
              p += 8;
            }
            if (localOffset == 0xFFFFFFFF && p + 8 <= limit) {
              localOffset = cv.getUint64(p, Endian.little);
            }
            found = true;
            break;
          }
          e += 4 + size;
        }
        if (!found) {
          throw const UnsafeArchiveException('Corrupt ZIP64 entry');
        }
      }

      if (isUnsafeArchivePath(name)) {
        throw const UnsafeArchiveException('Unsafe path in archive');
      }
      if (!seen.add(name)) {
        throw const UnsafeArchiveException('Duplicate path in archive');
      }
      if (uncompressed < 0 || uncompressed > limits.maxEntryBytes) {
        throw const UnsafeArchiveException('Archive entry is too large');
      }
      declaredTotal += uncompressed;
      if (declaredTotal > limits.maxTotalBytes) {
        throw const UnsafeArchiveException('Archive is too large');
      }
      if (compressed < 0 || localOffset < 0 || localOffset >= length) {
        throw const UnsafeArchiveException('Corrupt central directory');
      }

      final isUnix = (versionMadeBy >> 8) == 3;
      final unixMode = externalAttrs >> 16;
      final isSymlink = isUnix && (unixMode & 0xF000) == 0xA000;
      final isDirectory =
          name.endsWith('/') ||
          (isUnix && (unixMode & 0xF000) == 0x4000) ||
          (externalAttrs & 0x10) != 0;

      entries.add(
        SafeZipEntry(
          name: name,
          method: method,
          flags: flags,
          crc32: crc,
          compressedSize: compressed,
          uncompressedSize: uncompressed,
          localHeaderOffset: localOffset,
          isDirectory: isDirectory,
          isSymlink: isSymlink,
        ),
      );
      pos = end;
    }
    return entries;
  }

  static String _decodeName(Uint8List bytes, {required bool utf8Flag}) {
    try {
      return const Utf8Decoder().convert(bytes);
    } on FormatException {
      if (utf8Flag) rethrow;
      // Legacy CP437 names: map bytes 1:1 (only ASCII matters for paths).
      return String.fromCharCodes(bytes);
    }
  }
}

/// True for archive names that could escape the extraction root.
bool isUnsafeArchivePath(String path) {
  if (path.isEmpty) return true;
  if (path.contains('\u0000')) return true;
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('/')) return true;
  if (RegExp(r'^[A-Za-z]:').hasMatch(normalized)) return true;
  for (final segment in normalized.split('/')) {
    if (segment == '..') return true;
  }
  return false;
}

/// Resolves a relative link found in [fromFile] (an archive path) to a
/// normalized archive path, or null when it escapes the archive root.
String? resolveArchiveLink(String fromFile, String link) {
  if (link.isEmpty || link.contains('\u0000')) return null;
  var target = link.replaceAll('\\', '/');
  if (target.startsWith('/') || target.contains(':')) return null;
  final parts = fromFile.split('/')..removeLast();
  for (final segment in target.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  target = parts.join('/');
  return target.isEmpty ? null : target;
}
