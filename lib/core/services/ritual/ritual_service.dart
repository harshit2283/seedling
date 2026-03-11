import '../../../data/datasources/local/objectbox_database.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/ritual.dart';
import '../ai/ritual_detection_service.dart';
import '../ai/models/ritual_candidate.dart';

/// Service for managing the full ritual lifecycle:
/// confirmation, tracking, due-date computation, status transitions.
class RitualService {
  final ObjectBoxDatabase _db;
  final RitualDetectionService _detector;

  RitualService(this._db, this._detector);

  // ============ CRUD ============

  /// Confirm a detected candidate as a ritual
  Future<Ritual> createFromCandidate(
    RitualCandidate candidate, {
    required String name,
    required int cadenceDays,
    int? preferredHour,
  }) async {
    final ritual = Ritual(
      name: name.trim().isEmpty ? candidate.sampleText : name.trim(),
      signature: candidate.signature,
      cadenceDays: cadenceDays,
      preferredHour: preferredHour,
      occurrenceCount: candidate.occurrences,
      lastObservedAt: candidate.lastSeen,
    );
    ritual.nextDueAt = _computeNextDueAt(ritual);
    await _db.saveRitual(ritual);
    return ritual;
  }

  Future<void> pauseRitual(int id) async {
    final ritual = _db.getRitual(id);
    if (ritual == null) return;
    ritual.status = RitualStatus.paused;
    await _db.saveRitual(ritual);
  }

  Future<void> activateRitual(int id) async {
    final ritual = _db.getRitual(id);
    if (ritual == null) return;
    ritual.status = RitualStatus.active;
    ritual.nextDueAt = _computeNextDueAt(ritual);
    await _db.saveRitual(ritual);
  }

  Future<void> archiveRitual(int id) async {
    final ritual = _db.getRitual(id);
    if (ritual == null) return;
    ritual.status = RitualStatus.archived;
    await _db.saveRitual(ritual);
  }

  Future<void> deleteRitual(int id) async {
    await _db.deleteRitual(id);
  }

  // ============ Tracking ============

  /// Called after an entry is saved — checks if it matches any active ritual
  /// and updates tracking fields accordingly.
  Future<void> updateAfterEntry(Entry entry) async {
    final content = entry.searchableContent.trim();
    if (content.isEmpty) return;

    final entrySignature = _detector.computeSignaturePublic(
      content,
      entry.createdAt,
    );
    if (entrySignature == null) return;

    final active = _db
        .getAllRituals()
        .where((r) => r.statusIndex == RitualStatus.active.index)
        .where((r) => r.signature == entrySignature)
        .toList();

    for (final ritual in active) {
      ritual.occurrenceCount++;
      ritual.lastObservedAt = entry.createdAt;
      ritual.nextDueAt = _computeNextDueAt(ritual);
      await _db.saveRitual(ritual);
    }
  }

  DateTime _computeNextDueAt(Ritual ritual) {
    final base = ritual.lastObservedAt ?? DateTime.now();
    return base.add(Duration(days: ritual.cadenceDays));
  }

  // ============ Queries ============

  List<Ritual> getActiveRituals() => _db
      .getAllRituals()
      .where((r) => r.statusIndex == RitualStatus.active.index)
      .toList();

  List<Ritual> getDueRituals() =>
      getActiveRituals().where((r) => r.isDue).toList();

  List<Ritual> getAllRituals() => _db.getAllRituals();
}
