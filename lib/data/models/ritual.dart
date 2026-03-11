import 'package:objectbox/objectbox.dart';

/// Status of a ritual in the user's life
enum RitualStatus { active, paused, archived }

extension RitualStatusExt on RitualStatus {
  String get label {
    switch (this) {
      case RitualStatus.active:
        return 'Active';
      case RitualStatus.paused:
        return 'Paused';
      case RitualStatus.archived:
        return 'Archived';
    }
  }

  String get emoji {
    switch (this) {
      case RitualStatus.active:
        return '🌱';
      case RitualStatus.paused:
        return '⏸';
      case RitualStatus.archived:
        return '🗂';
    }
  }
}

/// A confirmed recurring ritual that the user wants to track
@Entity()
class Ritual {
  @Id()
  int id = 0;

  /// UUID for cross-device sync
  late String uuid;

  /// Display name for the ritual (e.g., "Morning coffee walk")
  late String name;

  /// Signature from RitualDetectionService for matching new entries
  late String signature;

  /// Status stored as int for ObjectBox
  int statusIndex = RitualStatus.active.index;

  /// Get the status enum
  RitualStatus get status => RitualStatus.values[statusIndex];

  /// Set the status enum
  set status(RitualStatus s) => statusIndex = s.index;

  /// Expected days between occurrences (e.g., 1 = daily, 7 = weekly)
  late int cadenceDays;

  /// Preferred time of day for notification scheduling (hour 0-23, null = no preference)
  int? preferredHour;

  /// When this ritual was created/confirmed
  @Property(type: PropertyType.date)
  late DateTime createdAt;

  /// When the ritual was last observed (entry matched)
  @Property(type: PropertyType.date)
  DateTime? lastObservedAt;

  /// When the ritual is next expected
  @Property(type: PropertyType.date)
  DateTime? nextDueAt;

  /// Total number of times this ritual has been observed
  late int occurrenceCount;

  /// Default constructor for ObjectBox
  Ritual({
    this.id = 0,
    String? uuid,
    this.name = '',
    this.signature = '',
    this.statusIndex = 0,
    this.cadenceDays = 7,
    this.preferredHour,
    DateTime? createdAt,
    this.lastObservedAt,
    this.nextDueAt,
    this.occurrenceCount = 0,
  }) : uuid = uuid ?? _generateUuid(),
       createdAt = createdAt ?? DateTime.now();

  static String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${now.toRadixString(36)}-${(now * 31337).toRadixString(36)}';
  }

  /// Human-readable cadence description
  String get cadenceDescription {
    if (cadenceDays == 1) return 'Daily';
    if (cadenceDays == 3) return 'Every 3 days';
    if (cadenceDays == 7) return 'Weekly';
    if (cadenceDays == 14) return 'Biweekly';
    return 'Every $cadenceDays days';
  }

  /// Whether this ritual is currently due (past nextDueAt)
  bool get isDue {
    if (nextDueAt == null) return false;
    return DateTime.now().isAfter(nextDueAt!);
  }

  /// Days since last observed (null if never)
  int? get daysSinceLastObserved {
    if (lastObservedAt == null) return null;
    return DateTime.now().difference(lastObservedAt!).inDays;
  }
}
