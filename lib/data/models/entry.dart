import 'package:objectbox/objectbox.dart';

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
@Entity()
class Entry {
  @Id()
  int id = 0;

  /// When this memory was captured
  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// Type of entry - stored as int index for ObjectBox
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
  @Property(type: PropertyType.date)
  DateTime? deletedAt;

  // ============================================================================
  // AI Analysis Fields (Phase 4)
  // ============================================================================

  /// Primary detected theme (family, work, nature, etc.)
  String? detectedTheme;

  /// Comma-separated IDs of related entries
  String? connectionIds;

  /// User-curated manual links (comma-separated syncUUIDs of linked entries)
  /// Distinct from connectionIds which are AI-detected.
  String? manualLinkIds;

  /// Sentiment score from -1.0 (negative) to 1.0 (positive)
  double? sentimentScore;

  /// When AI last analyzed this entry
  @Property(type: PropertyType.date)
  DateTime? lastAnalyzedAt;

  // ============================================================================
  // Memory Capsule Fields (Phase 4.5)
  // ============================================================================

  /// When this capsule should unlock (null for non-capsule entries)
  @Property(type: PropertyType.date)
  DateTime? capsuleUnlockDate;

  // ============================================================================
  // Voice Transcription Fields (Phase 5)
  // ============================================================================

  /// On-device speech transcription of voice entries
  String? transcription;

  // ============================================================================
  // Cloud Sync Fields (Phase 5)
  // ============================================================================

  /// UUID for cross-device sync identification
  String? syncUUID;

  /// When this entry was last modified (for sync conflict resolution)
  @Property(type: PropertyType.date)
  DateTime? modifiedAt;

  /// Device identifier that last modified this entry
  String? deviceId;

  /// True when one or more encrypted fields could not be decrypted at read-time.
  @Transient()
  bool decryptionFailed = false;

  /// Default constructor required by ObjectBox
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
    this.connectionIds,
    this.manualLinkIds,
    this.sentimentScore,
    this.lastAnalyzedAt,
    this.capsuleUnlockDate,
    this.transcription,
    this.syncUUID,
    this.modifiedAt,
    this.deviceId,
  }) : createdAt = createdAt ?? DateTime.now();

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

  /// Get list of connected entry IDs
  List<int> get connectedIds {
    if (connectionIds == null || connectionIds!.isEmpty) return [];
    return connectionIds!
        .split(',')
        .map((id) => int.tryParse(id.trim()))
        .whereType<int>()
        .toList();
  }

  /// Set connected entry IDs
  set connectedIds(List<int> ids) {
    connectionIds = ids.isEmpty ? null : ids.join(',');
  }

  /// Check if entry has been analyzed by AI
  bool get hasBeenAnalyzed => lastAnalyzedAt != null;

  /// Check if entry has a detected theme
  bool get hasTheme => detectedTheme != null && detectedTheme!.isNotEmpty;

  /// Check if entry has connections to other entries
  bool get hasConnections => connectionIds != null && connectionIds!.isNotEmpty;

  /// Get list of manually linked entry syncUUIDs
  List<String> get manualLinkList =>
      manualLinkIds?.split(',').where((s) => s.isNotEmpty).toList() ?? [];

  /// Whether this entry has manual links
  bool get hasManualLinks => manualLinkIds != null && manualLinkIds!.isNotEmpty;

  /// Get all searchable text content for analysis
  String get searchableContent {
    final parts = <String>[];
    if (text != null && text!.isNotEmpty) parts.add(text!);
    if (title != null && title!.isNotEmpty) parts.add(title!);
    if (context != null && context!.isNotEmpty) parts.add(context!);
    if (mood != null && mood!.isNotEmpty) parts.add(mood!);
    if (transcription != null && transcription!.isNotEmpty) {
      parts.add(transcription!);
    }
    return parts.join(' ').toLowerCase();
  }

  // ============================================================================
  // Memory Capsule Helper Methods (Phase 4.5)
  // ============================================================================

  /// Whether this entry is a time capsule
  bool get isCapsule => capsuleUnlockDate != null;

  /// Whether the capsule is still locked (hasn't reached unlock date)
  bool get isLocked => isCapsule && DateTime.now().isBefore(capsuleUnlockDate!);

  /// Whether the capsule has been unlocked (past unlock date)
  bool get isUnlocked => isCapsule && !isLocked;

  /// Days remaining until capsule unlocks (0 if already unlocked or not a capsule)
  int get daysUntilUnlock {
    if (!isCapsule || isUnlocked) return 0;
    return capsuleUnlockDate!.difference(DateTime.now()).inDays;
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
      capsuleUnlockDate: unlockDate,
    );
  }
}
