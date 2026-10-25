/// Entry types for different memory capture methods
enum EntryType {
  line, // Text - a line that stayed with you
  photo, // Image capture
  voice, // Voice memo
  object, // Physical object photo + note
  fragment, // Incomplete thought, no explanation needed
  ritual, // Recurring meaningful moment
  release, // "Let go" - acknowledging and releasing
}

/// A single memory entry in the user's tree
///
/// Core philosophy: All fields optional except id/createdAt
/// This supports "fragments without explanation" - not every
/// memory needs context or meaning attached to it.
class Entry {
  int id = 0;

  /// When this memory was captured
  DateTime createdAt;

  /// Type of entry, stored as its enum index
  int typeIndex;

  /// Get the EntryType enum value
  EntryType get type => EntryType.values[typeIndex];

  /// Set the EntryType enum value
  set type(EntryType value) => typeIndex = value.index;

  /// Text content (for LINE, FRAGMENT entries, or notes)
  String? text;

  /// Path to media file (photo, voice)
  String? mediaPath;

  /// Optional title/label
  String? title;

  /// Optional context or where/when
  String? context;

  /// Mood or feeling associated (optional)
  String? mood;

  /// Tags for organization (comma-separated)
  String? tags;

  /// Whether this has been "released" (for RELEASE entries)
  bool isReleased;

  /// Soft delete flag - entry is hidden but recoverable for 30 days
  bool isDeleted;

  /// When the entry was soft deleted (null if not deleted)
  DateTime? deletedAt;

  // ============================================================================
  // AI Analysis Fields (Phase 4)
  // ============================================================================

  /// Primary detected theme (family, work, nature, etc.)
  String? detectedTheme;

  /// User-curated manual links (comma-separated syncUUIDs of linked entries).
  /// Related memories are computed on the fly, never stored.
  String? manualLinkIds;

  // ============================================================================
  // Memory Capsule Fields (Phase 4.5)
  // ============================================================================

  /// When this capsule should unlock (null for non-capsule entries)
  DateTime? capsuleUnlockDate;

  // ============================================================================
  // Voice Transcription Fields (Phase 5)
  // ============================================================================

  /// On-device speech transcription of voice entries
  String? transcription;

  // ============================================================================
  // Cloud Sync Fields (Phase 5)
  // ============================================================================

  /// UUID for cross-device sync identification.
  ///
  /// Indexed: sync merge and manual link resolution look entries up by this
  /// on every record.
  String? syncUUID;

  /// When this entry was last modified (for sync conflict resolution)
  DateTime? modifiedAt;

  /// Device identifier that last modified this entry
  String? deviceId;

  /// Remote id of this entry's encrypted media blob (null until uploaded,
  /// or for entries without media). With [mediaPath] null it means the file
  /// still has to be downloaded.
  String? mediaAssetId;

  /// Base64 per-file key for the media blob. Stored in the encrypted
  /// database with everything else; synced only inside the encrypted record.
  String? mediaKey;

  String? _searchCache;

  Entry({
    this.id = 0,
    DateTime? createdAt,
    this.typeIndex = 0,
    this.text,
    this.mediaPath,
    this.title,
    this.context,
    this.mood,
    this.tags,
    this.isReleased = false,
    this.isDeleted = false,
    this.deletedAt,
    this.detectedTheme,
    this.manualLinkIds,
    this.capsuleUnlockDate,
    this.transcription,
    this.syncUUID,
    this.modifiedAt,
    this.deviceId,
    this.mediaAssetId,
    this.mediaKey,
  }) : createdAt = createdAt ?? DateTime.now();

  /// A field-for-field copy of the persisted fields.
  Entry copy() => Entry(
    id: id,
    createdAt: createdAt,
    typeIndex: typeIndex,
    text: text,
    mediaPath: mediaPath,
    title: title,
    context: context,
    mood: mood,
    tags: tags,
    isReleased: isReleased,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
    detectedTheme: detectedTheme,
    manualLinkIds: manualLinkIds,
    capsuleUnlockDate: capsuleUnlockDate,
    transcription: transcription,
    syncUUID: syncUUID,
    modifiedAt: modifiedAt,
    deviceId: deviceId,
    mediaAssetId: mediaAssetId,
    mediaKey: mediaKey,
  );

  /// Create a LINE entry - text that stayed with you
  factory Entry.line({String? text, String? context, String? mood}) {
    return Entry(
      typeIndex: EntryType.line.index,
      text: text,
      context: context,
      mood: mood,
    );
  }

  /// Create a PHOTO entry
  factory Entry.photo({
    required String mediaPath,
    String? text,
    String? title,
    String? context,
  }) {
    return Entry(
      typeIndex: EntryType.photo.index,
      mediaPath: mediaPath,
      text: text,
      title: title,
      context: context,
    );
  }

  /// Create a VOICE entry
  factory Entry.voice({
    required String mediaPath,
    String? text,
    String? title,
  }) {
    return Entry(
      typeIndex: EntryType.voice.index,
      mediaPath: mediaPath,
      text: text,
      title: title,
    );
  }

  /// Create an OBJECT entry - physical object with memory
  factory Entry.object({
    String? mediaPath,
    String? text,
    required String title,
    String? context,
  }) {
    return Entry(
      typeIndex: EntryType.object.index,
      mediaPath: mediaPath,
      text: text,
      title: title,
      context: context,
    );
  }

  /// Create a FRAGMENT entry - incomplete thought, no explanation needed
  factory Entry.fragment({String? text}) {
    return Entry(typeIndex: EntryType.fragment.index, text: text);
  }

  /// Create a RITUAL entry - recurring meaningful moment
  factory Entry.ritual({String? text, required String title, String? context}) {
    return Entry(
      typeIndex: EntryType.ritual.index,
      text: text,
      title: title,
      context: context,
    );
  }

  /// Create a RELEASE entry - acknowledging and letting go
  factory Entry.release({String? text}) {
    return Entry(
      typeIndex: EntryType.release.index,
      text: text,
      isReleased: true,
    );
  }

  /// Get a display-friendly type name
  String get typeName {
    switch (type) {
      case EntryType.line:
        return 'Line';
      case EntryType.photo:
        return 'Photo';
      case EntryType.voice:
        return 'Voice';
      case EntryType.object:
        return 'Object';
      case EntryType.fragment:
        return 'Fragment';
      case EntryType.ritual:
        return 'Ritual';
      case EntryType.release:
        return 'Released';
    }
  }

  /// Get the primary display content
  String get displayContent {
    if (text != null && text!.isNotEmpty) return text!;
    if (title != null && title!.isNotEmpty) return title!;
    return typeName;
  }

  /// Check if entry has any text content
  bool get hasText => text != null && text!.isNotEmpty;

  /// Check if entry has media
  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;

  // ============================================================================
  // AI Helper Methods (Phase 4)
  // ============================================================================

  /// Check if entry has a detected theme
  bool get hasTheme => detectedTheme != null && detectedTheme!.isNotEmpty;

  /// Get list of manually linked entry syncUUIDs
  List<String> get manualLinkList =>
      manualLinkIds?.split(',').where((s) => s.isNotEmpty).toList() ?? [];

  /// Whether this entry has manual links
  bool get hasManualLinks => manualLinkIds != null && manualLinkIds!.isNotEmpty;

  /// Get all searchable text content for analysis
  String get searchableContent {
    return searchableLower;
  }

  /// Memoised lowercased searchable content. Cached per-instance because
  /// filter loops call this for every entry on every keystroke.
  String get searchableLower {
    final cached = _searchCache;
    if (cached != null) return cached;
    final parts = <String>[];
    if (text != null && text!.isNotEmpty) parts.add(text!);
    if (title != null && title!.isNotEmpty) parts.add(title!);
    if (context != null && context!.isNotEmpty) parts.add(context!);
    if (mood != null && mood!.isNotEmpty) parts.add(mood!);
    if (transcription != null && transcription!.isNotEmpty) {
      parts.add(transcription!);
    }
    final value = parts.join(' ').toLowerCase();
    _searchCache = value;
    return value;
  }

  /// Drop the memoised searchable string so the next read recomputes from the
  /// current text/title/transcription fields. Called after an edit.
  void invalidateSearchCache() {
    _searchCache = null;
  }

  // ============================================================================
  // Memory Capsule Helper Methods (Phase 4.5)
  // ============================================================================

  /// Whether this entry is a time capsule
  bool get isCapsule => capsuleUnlockDate != null;

  /// Whether the capsule is still locked (hasn't reached unlock date)
  bool get isLocked =>
      isCapsule && DateTime.now().toUtc().isBefore(capsuleUnlockDate!.toUtc());

  /// Whether the capsule has been unlocked (past unlock date)
  bool get isUnlocked => isCapsule && !isLocked;

  /// Days remaining until capsule unlocks (0 if already unlocked or not a capsule)
  int get daysUntilUnlock {
    if (!isCapsule || isUnlocked) return 0;
    return capsuleUnlockDate!.toUtc().difference(DateTime.now().toUtc()).inDays;
  }

  /// Human-readable time until unlock
  String get unlockTimeDescription {
    if (!isCapsule) return '';
    if (isUnlocked) return 'Unlocked';

    final days = daysUntilUnlock;
    if (days == 0) return 'Unlocks today';
    if (days == 1) return 'Unlocks tomorrow';
    if (days < 30) return 'Unlocks in $days days';
    if (days < 365) {
      final months = (days / 30).round();
      return 'Unlocks in $months month${months > 1 ? 's' : ''}';
    }
    final years = (days / 365).round();
    return 'Unlocks in $years year${years > 1 ? 's' : ''}';
  }

  /// Create a LINE capsule - text to be revealed later
  factory Entry.capsule({
    String? text,
    required DateTime unlockDate,
    String? context,
    String? mood,
  }) {
    return Entry(
      typeIndex: EntryType.line.index,
      text: text,
      context: context,
      mood: mood,
      capsuleUnlockDate: unlockDate.toUtc(),
    );
  }
}
