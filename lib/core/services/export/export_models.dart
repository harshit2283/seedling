// Plain data types shared by export, import and restore. Kept free of
// Flutter imports so they can cross isolate boundaries.

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  const ExportResult.success(this.filePath) : success = true, error = null;
  const ExportResult.failure(this.error) : success = false, filePath = null;
}

/// Result of an encrypted import operation
class ImportResult {
  final bool success;
  final String? error;
  final int importedEntries;
  final int importedMediaFiles;
  final int skippedDuplicates;
  final List<String> warnings;

  const ImportResult.success({
    required this.importedEntries,
    required this.importedMediaFiles,
    this.skippedDuplicates = 0,
    this.warnings = const [],
  }) : success = true,
       error = null;

  const ImportResult.failure(this.error)
    : success = false,
      importedEntries = 0,
      importedMediaFiles = 0,
      skippedDuplicates = 0,
      warnings = const [];
}

/// Preview metadata for an encrypted backup.
class EncryptedBackupPreview {
  final int entryCount;
  final int mediaCount;
  final int version;
  final DateTime? exportedAt;
  final bool integrityVerified;
  final String? kdf;
  final int? iterations;

  const EncryptedBackupPreview({
    required this.entryCount,
    required this.mediaCount,
    required this.version,
    this.exportedAt,
    this.integrityVerified = false,
    this.kdf,
    this.iterations,
  });
}

/// Fully loaded encrypted backup payload.
class LoadedEncryptedBackup {
  final EncryptedBackupPreview preview;
  final List<Map<String, dynamic>> entries;
  final Map<String, List<int>> mediaFiles;
  final List<String> warnings;

  const LoadedEncryptedBackup({
    required this.preview,
    required this.entries,
    required this.mediaFiles,
    this.warnings = const [],
  });
}
