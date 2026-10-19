/// A description of "what the user wants to capture", decoupled from the UI.
///
/// The capture sheet builds one of these and hands it to the entry creator.
/// Tests can construct intents directly without touching widgets, and the
/// creator can grow new entry types without growing the sheet's switch.
sealed class CaptureIntent {
  const CaptureIntent();

  /// Optional capsule unlock date applied uniformly to any intent type.
  DateTime? get capsuleUnlockDate;
}

class LineCapture extends CaptureIntent {
  final String text;
  @override
  final DateTime? capsuleUnlockDate;
  const LineCapture(this.text, {this.capsuleUnlockDate});
}

class FragmentCapture extends CaptureIntent {
  final String? text;
  @override
  final DateTime? capsuleUnlockDate;
  const FragmentCapture(this.text, {this.capsuleUnlockDate});
}

class ReleaseCapture extends CaptureIntent {
  final String? text;
  @override
  final DateTime? capsuleUnlockDate;
  const ReleaseCapture(this.text, {this.capsuleUnlockDate});
}

class PhotoCapture extends CaptureIntent {
  final String mediaPath;
  final String? text;
  @override
  final DateTime? capsuleUnlockDate;
  const PhotoCapture({
    required this.mediaPath,
    this.text,
    this.capsuleUnlockDate,
  });
}

class VoiceCapture extends CaptureIntent {
  final String mediaPath;
  final String? text;
  final String? title;
  @override
  final DateTime? capsuleUnlockDate;
  const VoiceCapture({
    required this.mediaPath,
    this.text,
    this.title,
    this.capsuleUnlockDate,
  });
}

class ObjectCapture extends CaptureIntent {
  final String title;
  final String? mediaPath;
  final String? text;
  final String? context;
  @override
  final DateTime? capsuleUnlockDate;
  const ObjectCapture({
    required this.title,
    this.mediaPath,
    this.text,
    this.context,
    this.capsuleUnlockDate,
  });
}

class RitualCapture extends CaptureIntent {
  final String title;
  final String? text;
  final String? context;
  @override
  final DateTime? capsuleUnlockDate;
  const RitualCapture({
    required this.title,
    this.text,
    this.context,
    this.capsuleUnlockDate,
  });
}

class CapsuleCapture extends CaptureIntent {
  final String? text;
  final DateTime unlockDate;
  const CapsuleCapture({required this.unlockDate, this.text});

  @override
  DateTime? get capsuleUnlockDate => unlockDate;
}
