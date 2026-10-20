import '../../../data/models/entry.dart';

/// A recurring moment the person has named: every ritual memory that shares
/// a title (ignoring case and spacing) belongs to the same ritual.
class RitualMemoryGroup {
  /// The ritual's name, as the person last wrote it.
  final String title;

  /// Occurrences, newest first.
  final List<Entry> occurrences;

  const RitualMemoryGroup({required this.title, required this.occurrences});

  int get count => occurrences.length;
  DateTime get lastAt => occurrences.first.createdAt;
  DateTime get firstAt => occurrences.last.createdAt;
}

/// Normalised grouping key for a ritual title.
String ritualKey(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Groups the person's ritual memories by title. Deleted memories and
/// capsules that are still waiting to open are left out. Groups are ordered
/// by their most recent occurrence.
List<RitualMemoryGroup> groupRitualMemories(Iterable<Entry> entries) {
  final groups = <String, List<Entry>>{};
  for (final entry in entries) {
    if (entry.type != EntryType.ritual) continue;
    if (entry.isDeleted || entry.isLocked) continue;
    final name = _nameFor(entry);
    if (name == null) continue;
    groups.putIfAbsent(ritualKey(name), () => []).add(entry);
  }

  final result = <RitualMemoryGroup>[];
  for (final list in groups.values) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    result.add(
      RitualMemoryGroup(title: _nameFor(list.first)!, occurrences: list),
    );
  }
  result.sort((a, b) => b.lastAt.compareTo(a.lastAt));
  return result;
}

String? _nameFor(Entry entry) {
  final title = entry.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final text = entry.text?.trim();
  if (text == null || text.isEmpty) return null;
  return text.split('\n').first.trim();
}
