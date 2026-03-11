class RitualCandidate {
  final String signature;
  final int occurrences;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String sampleText;

  const RitualCandidate({
    required this.signature,
    required this.occurrences,
    required this.firstSeen,
    required this.lastSeen,
    required this.sampleText,
  });

  int get spanDays => lastSeen.difference(firstSeen).inDays;
  int get daysSinceLastSeen => DateTime.now().difference(lastSeen).inDays;
}
