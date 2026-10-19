import '../../../data/models/entry.dart';

/// Why a memory was brought back.
enum ResurfaceReason {
  /// Written on this calendar day in an earlier year.
  onThisDay,

  /// An older memory (at least [resurfaceMinAge] old), chosen for today.
  fromThePast,
}

/// Memories younger than this are still "recent" and never resurfaced as a
/// random pick; the home screen already shows recent memories.
const Duration resurfaceMinAge = Duration(days: 30);

/// One past memory chosen for the home screen today.
class ResurfacedMemory {
  final Entry entry;
  final ResurfaceReason reason;

  const ResurfacedMemory(this.entry, this.reason);

  /// Whole calendar years between the memory and [today].
  int yearsAgo(DateTime today) => today.year - entry.createdAt.year;
}

/// Whether [entry] may ever be resurfaced: not in the trash, not a capsule
/// that is still sealed, and not something the person chose to let go of.
bool isResurfaceable(Entry entry, {DateTime? now}) {
  if (entry.isDeleted) return false;
  if (entry.type == EntryType.release) return false;
  final unlock = entry.capsuleUnlockDate;
  if (unlock != null) {
    final at = (now ?? DateTime.now()).toUtc();
    if (at.isBefore(unlock.toUtc())) return false;
  }
  return true;
}

/// A stable, well-mixed number for a calendar date, so the pick rotates once
/// a day and stays the same all day (and across app restarts).
int resurfaceDaySeed(DateTime day) {
  var x = day.year * 10000 + day.month * 100 + day.day;
  // 32-bit integer hash (Wang-style); kept positive.
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0x7fffffff;
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0x7fffffff;
  x = (x >> 16) ^ x;
  return x & 0x7fffffff;
}

/// Picks today's memory from [entries]:
///
/// 1. a memory from this day in an earlier year, if there is one;
/// 2. otherwise any memory at least [resurfaceMinAge] old.
///
/// The choice is deterministic for a given [today] and set of entries.
/// Returns null when nothing is old enough yet.
ResurfacedMemory? pickResurfacedMemory(List<Entry> entries, DateTime today) {
  final eligible = entries.where((e) => isResurfaceable(e, now: today)).toList()
    // Sort so the pick does not depend on the order the database returned.
    ..sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  if (eligible.isEmpty) return null;
  final seed = resurfaceDaySeed(today);

  final onThisDay = eligible.where((e) {
    final created = e.createdAt.toLocal();
    return created.year < today.year &&
        created.month == today.month &&
        created.day == today.day;
  }).toList();
  if (onThisDay.isNotEmpty) {
    return ResurfacedMemory(
      onThisDay[seed % onThisDay.length],
      ResurfaceReason.onThisDay,
    );
  }

  final startOfToday = DateTime(today.year, today.month, today.day);
  final cutoff = startOfToday.subtract(resurfaceMinAge);
  final older = eligible
      .where((e) => !e.createdAt.toLocal().isAfter(cutoff))
      .toList();
  if (older.isEmpty) return null;
  return ResurfacedMemory(
    older[seed % older.length],
    ResurfaceReason.fromThePast,
  );
}

/// The key a day-scoped dismissal is stored under, e.g. `2026-10-19`.
String resurfaceDayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
