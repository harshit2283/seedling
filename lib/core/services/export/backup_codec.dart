import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'export_models.dart';
import 'safe_zip.dart';

/// Encrypted backup format constants and the CPU-heavy work (KDF, AES-GCM,
/// ZIP parsing) behind it. Everything here is top-level and free of Flutter
/// bindings so it can run inside `Isolate.run`.
abstract final class BackupCodec {
  static const int formatVersion = 1;

  /// PBKDF2-HMAC-SHA256 iterations (OWASP 2023 guidance). Backups are
  /// written and accepted with exactly this count, so a crafted file can't
  /// make "Unlock" run a weaker or an endless KDF.
  static const int pbkdf2Iterations = 600000;

  static const String kdf = 'pbkdf2-sha256';
  static const String signatureAlgorithm = 'hmac-sha256';
  static const int maxEncryptedBackupBytes = 300 * 1024 * 1024;

  /// Limits for the ZIP inside a backup / a plain ZIP archive export.
  static const SafeZipLimits archiveLimits = SafeZipLimits(
    maxEntries: 12000,
    maxTotalBytes: 800 * 1024 * 1024,
    maxEntryBytes: 512 * 1024 * 1024,
  );
}

/// Encrypts [zipBytes] with [passphrase] and writes the `.seedling` payload
/// to [outputPath]. Run inside an isolate.
Future<void> writeEncryptedBackupFile({
  required List<int> zipBytes,
  required String passphrase,
  required int iterations,
  required String outputPath,
}) async {
  final salt = _randomBytes(16);
  final nonce = _randomBytes(12);
  final key = await _deriveKey(passphrase, salt, iterations);
  final secretBox = await AesGcm.with256bits().encrypt(
    zipBytes,
    secretKey: key,
    nonce: nonce,
  );

  final payload = <String, dynamic>{
    'version': BackupCodec.formatVersion,
    'kdf': BackupCodec.kdf,
    'iterations': iterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(secretBox.nonce),
    'mac': base64Encode(secretBox.mac.bytes),
    'ciphertext': base64Encode(secretBox.cipherText),
    'sigAlg': BackupCodec.signatureAlgorithm,
  };
  payload['signature'] = await _computePayloadSignature(payload, key);
  await File(outputPath).writeAsString(jsonEncode(payload), flush: true);
}

/// Reads, decrypts and unpacks an encrypted backup. Run inside an isolate.
///
/// Throws [SecretBoxAuthenticationError] for a wrong passphrase and
/// [FormatException] for malformed, oversized or unsafe input. The KDF
/// parameters must be exactly [iterations] (the current ones), checked
/// *before* the KDF runs.
Future<LoadedEncryptedBackup> readEncryptedBackupFile(
  String filePath,
  String passphrase, {
  int iterations = BackupCodec.pbkdf2Iterations,
}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw const FormatException('Backup file not found');
  }
  if (await file.length() > BackupCodec.maxEncryptedBackupBytes) {
    throw const FormatException('Backup file is too large');
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid backup metadata');
  }
  final payload = decoded;
  final version = payload['version'];
  if (version != BackupCodec.formatVersion) {
    throw const FormatException('Unsupported backup version');
  }
  if (payload['kdf'] != BackupCodec.kdf ||
      payload['iterations'] != iterations) {
    throw const FormatException('Invalid backup metadata');
  }

  final salt = base64Decode(payload['salt'] as String);
  final nonce = base64Decode(payload['nonce'] as String);
  final macBytes = base64Decode(payload['mac'] as String);
  final ciphertext = base64Decode(payload['ciphertext'] as String);
  if (salt.length != 16 || nonce.length != 12 || macBytes.length != 16) {
    throw const FormatException('Invalid backup encryption metadata');
  }

  final key = await _deriveKey(passphrase, salt, iterations);
  final zipBytes = await AesGcm.with256bits().decrypt(
    SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
    secretKey: key,
  );
  await _verifyPayloadSignature(payload, key);

  final archive = readSeedlingArchive(
    SafeZipReader.fromBytes(
      zipBytes is Uint8List ? zipBytes : Uint8List.fromList(zipBytes),
      limits: BackupCodec.archiveLimits,
    ),
  );

  return LoadedEncryptedBackup(
    preview: EncryptedBackupPreview(
      entryCount: archive.entries.length,
      mediaCount: archive.mediaFiles.length,
      version: version as int,
      exportedAt: DateTime.tryParse(archive.exportedAt ?? ''),
    ),
    entries: archive.entries,
    mediaFiles: archive.mediaFiles,
  );
}

/// Loads a plain Seedling ZIP archive (entries.json + media). Run inside an
/// isolate.
LoadedEncryptedBackup readZipArchiveFile(String filePath) {
  final archive = readSeedlingArchive(
    SafeZipReader.fromFile(filePath, limits: BackupCodec.archiveLimits),
  );
  final manifest = archive.manifest;
  final warnings = <String>[];
  if (manifest['format'] != null && manifest['format'] != 'seedling-archive') {
    warnings.add('unknown_archive_format');
  }
  final manifestVersion = manifest['version'];
  return LoadedEncryptedBackup(
    preview: EncryptedBackupPreview(
      entryCount: archive.entries.length,
      mediaCount: archive.mediaFiles.length,
      version: manifestVersion is int ? manifestVersion : 1,
      exportedAt: DateTime.tryParse(
        (manifest['exportedAt'] as String?) ?? archive.exportedAt ?? '',
      ),
    ),
    entries: archive.entries,
    mediaFiles: archive.mediaFiles,
    warnings: warnings,
  );
}

/// Parsed content of a Seedling archive (shared by plain and encrypted).
class SeedlingArchiveContent {
  final List<Map<String, dynamic>> entries;
  final Map<String, List<int>> mediaFiles;
  final Map<String, dynamic> manifest;
  final String? exportedAt;

  const SeedlingArchiveContent({
    required this.entries,
    required this.mediaFiles,
    required this.manifest,
    required this.exportedAt,
  });
}

/// Reads entries.json, manifest.json and media/ from [reader], then closes it.
/// Sizes were validated when [reader] opened; every read is size-bounded.
SeedlingArchiveContent readSeedlingArchive(SafeZipReader reader) {
  try {
    final entriesFile = reader.find('entries.json');
    if (entriesFile == null) {
      throw const FormatException('entries.json missing');
    }
    final parsed = jsonDecode(utf8.decode(reader.readBytes(entriesFile)));
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('entries.json is malformed');
    }
    final entries = (parsed['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    var manifest = const <String, dynamic>{};
    final manifestFile = reader.find('manifest.json');
    if (manifestFile != null) {
      try {
        final decoded = jsonDecode(utf8.decode(reader.readBytes(manifestFile)));
        if (decoded is Map<String, dynamic>) manifest = decoded;
      } on FormatException {
        manifest = const {};
      }
    }

    final mediaFiles = <String, List<int>>{};
    for (final entry in reader.files) {
      if (!entry.name.startsWith('media/')) continue;
      mediaFiles[entry.name] = reader.readBytes(entry);
    }

    return SeedlingArchiveContent(
      entries: entries,
      mediaFiles: mediaFiles,
      manifest: manifest,
      exportedAt: parsed['exportedAt'] as String?,
    );
  } finally {
    reader.close();
  }
}

Future<SecretKey> _deriveKey(
  String passphrase,
  List<int> salt,
  int iterations,
) {
  return Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

String _canonicalPayloadString(Map<String, dynamic> payload) {
  return [
    payload['version']?.toString() ?? '',
    payload['kdf']?.toString() ?? '',
    payload['iterations']?.toString() ?? '',
    payload['salt']?.toString() ?? '',
    payload['nonce']?.toString() ?? '',
    payload['mac']?.toString() ?? '',
    payload['ciphertext']?.toString() ?? '',
    payload['sigAlg']?.toString() ?? '',
  ].join('|');
}

Future<String> _computePayloadSignature(
  Map<String, dynamic> payload,
  SecretKey key,
) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode(_canonicalPayloadString(payload)),
    secretKey: key,
  );
  return base64Encode(mac.bytes);
}

/// Throws unless [payload] carries a valid signature.
Future<void> _verifyPayloadSignature(
  Map<String, dynamic> payload,
  SecretKey key,
) async {
  if (payload['sigAlg'] != BackupCodec.signatureAlgorithm) {
    throw const FormatException('Unsupported backup integrity algorithm');
  }
  final expected = await _computePayloadSignature(payload, key);
  if (payload['signature'] != expected) {
    throw const FormatException('Backup integrity check failed');
  }
}
