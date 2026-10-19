import '../../../data/models/entry.dart';

/// Lines shorter than this are kept as fragments: "an incomplete thought".
///
/// The capture sheet no longer asks people to choose between Line and
/// Fragment. A very short line simply *is* a fragment, which keeps the
/// distinction in the data (and in older exports) without a decision in the
/// moment. Matches the threshold the share extension already uses.
const int fragmentMaxLength = 15;

/// Whether [text] reads as a fragment rather than a full line.
bool isFragmentText(String text) => text.trim().length < fragmentMaxLength;

/// Infers what a draft in the capture sheet will be saved as, from what the
/// person actually added — never from a type they had to pick first.
///
/// [explicit] is only honoured for the deliberate modes that cannot be
/// inferred: [EntryType.release] ("let go") and [EntryType.ritual].
///
/// Order of precedence:
/// 1. an explicit Let go / Ritual choice,
/// 2. a voice recording → [EntryType.voice] (a title is kept as its title),
/// 3. a title → [EntryType.object] (with the photo, if there is one),
/// 4. a photo → [EntryType.photo],
/// 5. otherwise text: [EntryType.fragment] when very short, else
///    [EntryType.line].
EntryType inferCaptureType({
  String text = '',
  String title = '',
  bool hasPhoto = false,
  bool hasVoice = false,
  EntryType? explicit,
}) {
  if (explicit == EntryType.release) return EntryType.release;
  if (explicit == EntryType.ritual) return EntryType.ritual;
  if (hasVoice) return EntryType.voice;
  if (title.trim().isNotEmpty) return EntryType.object;
  if (hasPhoto) return EntryType.photo;
  return isFragmentText(text) ? EntryType.fragment : EntryType.line;
}
