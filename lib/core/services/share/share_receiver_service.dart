import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../../data/models/entry.dart';

/// Represents content shared from another app to Seedling
class SharedContent {
  static const int maxSharedTextLength = 10000;
  static const int maxSharedImageBytes = 25 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
  };

  final SharedContentType type;
  final String? text;
  final String? imagePath;
  final String? url;
  final EntryType? suggestedType;

  SharedContent({
    required this.type,
    this.text,
    this.imagePath,
    this.url,
    this.suggestedType,
  });

  /// Create from a shared media file
  factory SharedContent.fromMediaFile(SharedMediaFile file) {
    switch (file.type) {
      case SharedMediaType.image:
        final imagePath = file.path;
        if (!_isValidSharedImagePath(imagePath)) {
          return SharedContent(type: SharedContentType.text, text: null);
        }
        return SharedContent(
          type: SharedContentType.image,
          imagePath: imagePath,
          text: _sanitizeSharedText(file.message),
        );
      case SharedMediaType.text:
        return SharedContent._fromText(file.path);
      case SharedMediaType.url:
        final trimmedUrl = file.path.trim();
        if (!_isSafeHttpUrl(trimmedUrl)) {
          return SharedContent(type: SharedContentType.text, text: null);
        }
        return SharedContent(
          type: SharedContentType.url,
          url: trimmedUrl,
          text: _sanitizeSharedText(trimmedUrl),
        );
      default:
        // Video, file - not supported, treat as text if possible
        return SharedContent(
          type: SharedContentType.text,
          text: _sanitizeSharedText(file.message ?? file.path),
        );
    }
  }

  /// Create from shared text string
  factory SharedContent._fromText(String text) {
    final sanitized = _sanitizeSharedText(text);
    if (sanitized == null) {
      return SharedContent(type: SharedContentType.text, text: null);
    }

    // Check if it's a URL
    final urlPattern = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (urlPattern.hasMatch(sanitized.trim()) && _isSafeHttpUrl(sanitized)) {
      return SharedContent(
        type: SharedContentType.url,
        url: sanitized.trim(),
        text: sanitized.trim(),
        suggestedType: EntryType.line,
      );
    }

    return SharedContent(
      type: SharedContentType.text,
      text: sanitized,
      suggestedType: inferEntryType(sanitized),
    );
  }

  /// Infer the best entry type for shared text content.
  ///
  /// Checks for release keywords, ritual patterns, and short/vague text.
  /// Defaults to [EntryType.line] when no special pattern is detected.
  static EntryType inferEntryType(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    // Very short and vague text -> fragment
    if (trimmed.length < 15) {
      // Only classify as fragment if the text is truly vague
      // (no strong keywords that would match release/ritual)
      if (!_hasReleaseKeywords(lower) && !_hasRitualPatterns(lower)) {
        return EntryType.fragment;
      }
    }

    // Check for release/letting-go keywords
    if (_hasReleaseKeywords(lower)) {
      return EntryType.release;
    }

    // Check for ritual/routine patterns
    if (_hasRitualPatterns(lower)) {
      return EntryType.ritual;
    }

    // Default to line
    return EntryType.line;
  }

  static const List<String> _releaseKeywords = [
    'goodbye',
    'letting go',
    'moving on',
    'release',
    'forgive',
    'farewell',
    'closure',
    'surrender',
    'let go',
  ];

  static const List<String> _ritualPatterns = [
    'every morning',
    'each day',
    'weekly',
    'routine',
    'ritual',
    'tradition',
    'always do',
    'habit',
    'every night',
    'each week',
    'every day',
    'daily',
  ];

  static bool _hasReleaseKeywords(String lower) {
    return _releaseKeywords.any((kw) => lower.contains(kw));
  }

  static bool _hasRitualPatterns(String lower) {
    return _ritualPatterns.any((p) => lower.contains(p));
  }

  /// Whether this shared content has usable data
  bool get isValid {
    switch (type) {
      case SharedContentType.text:
      case SharedContentType.url:
        return text != null &&
            text!.trim().isNotEmpty &&
            text!.length <= maxSharedTextLength;
      case SharedContentType.image:
        return imagePath != null &&
            imagePath!.isNotEmpty &&
            _isValidSharedImagePath(imagePath!);
    }
  }

  static String? _sanitizeSharedText(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxSharedTextLength) return trimmed;
    return trimmed.substring(0, maxSharedTextLength);
  }

  static bool _isSafeHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static bool _isValidSharedImagePath(String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return false;
      if (file.lengthSync() > maxSharedImageBytes) return false;
      final extension = _extensionOf(imagePath);
      return _allowedImageExtensions.contains(extension);
    } catch (e) {
      debugPrint('ShareReceiver: image validation failed for $imagePath: $e');
      return false;
    }
  }

  static String _extensionOf(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex).toLowerCase();
  }
}

/// Types of content that can be shared to Seedling
enum SharedContentType {
  text, // Plain text -> LINE entry
  url, // URL -> LINE entry with URL
  image, // Image -> PHOTO entry
}

/// Service for receiving content shared from other apps
///
/// Handles both "share while app is open" and "share while app is closed"
/// scenarios. Content shared while closed is retrieved on app startup.
class ShareReceiverService {
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  final _contentController = StreamController<SharedContent>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of shared content received from other apps
  Stream<SharedContent> get sharedContentStream => _contentController.stream;

  /// Stream of user-facing share import errors.
  Stream<String> get sharedErrorStream => _errorController.stream;

  /// Initialize the service and start listening for shared content
  void init() {
    // Listen for shared content while app is running
    // In receive_sharing_intent 1.8+, all content comes through media stream
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
    );

    // Check for content shared while app was closed
    _checkInitialSharedContent();
  }

  /// Check for content that was shared while the app was not running
  Future<void> _checkInitialSharedContent() async {
    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      _handleSharedMedia(initialMedia);
    }
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    var handledAny = false;
    for (final file in files) {
      final content = SharedContent.fromMediaFile(file);
      if (content.isValid) {
        _contentController.add(content);
        handledAny = true;
      } else {
        _errorController.add(_unsupportedContentMessage(file));
      }
    }
    if (!handledAny && files.isNotEmpty) {
      debugPrint(
        'ShareReceiver: dropped ${files.length} unsupported share item(s)',
      );
    }
    // Clear the shared content after processing
    ReceiveSharingIntent.instance.reset();
  }

  String _unsupportedContentMessage(SharedMediaFile file) {
    return switch (file.type) {
      SharedMediaType.image =>
        'That image could not be imported into Seedling.',
      SharedMediaType.url => 'That link could not be imported into Seedling.',
      SharedMediaType.text => 'That text could not be imported into Seedling.',
      _ => 'That shared item is not supported yet.',
    };
  }

  /// Clean up resources
  void dispose() {
    _mediaSubscription?.cancel();
    _contentController.close();
    _errorController.close();
  }
}
