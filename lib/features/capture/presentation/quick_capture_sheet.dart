import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../app/theme/palette.dart';
import '../../../app/theme/radius.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/media/draft_media_tracker.dart';
import '../../../core/services/media/photo_capture_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/feedback/seedling_toast.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../data/models/entry.dart';
import '../domain/capture_inference.dart';
import '../domain/capture_intent.dart';
import 'widgets/release_ceremony.dart';
import 'widgets/voice_capture_content.dart';
import '../../../core/util/date_labels.dart';

/// What the draft in the capture sheet currently is, inferred from what was
/// added (see [inferCaptureType]). Kept for callers and tests that reason
/// about the sheet's mode.
enum CaptureMode {
  text, // Line, Fragment, Release, Ritual
  photo, // A photo is attached
  voice, // A voice memo is attached (or being recorded)
  object, // The memory has a title
}

/// Shows the quick capture sheet with platform-appropriate presentation
void showQuickCaptureSheet(
  BuildContext context, {
  String? initialText,
  bool startAsCapsule = false,
}) {
  HapticFeedback.lightImpact();

  if (PlatformUtils.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => QuickCaptureSheet(
        initialText: initialText,
        startAsCapsule: startAsCapsule,
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The route's own drag-to-dismiss pops without asking the sheet, so a
      // swipe would throw the draft away. The sheet handles the swipe itself
      // and saves before it closes.
      enableDrag: false,
      builder: (context) => QuickCaptureSheet(
        initialText: initialText,
        startAsCapsule: startAsCapsule,
      ),
    );
  }
}

/// Opens the capture sheet if onboarding asked for a first memory. Call
/// from the home screen once it is on screen.
void openPendingFirstCapture(BuildContext context, WidgetRef ref) {
  if (ref.read(pendingFirstCaptureProvider.notifier).consume()) {
    showQuickCaptureSheet(context);
  }
}

/// Quick capture bottom sheet for adding memories.
///
/// Philosophy: capture should feel like breathing, not documenting. The
/// sheet opens straight into a text field with the keyboard up. Attaching a
/// photo, holding the mic or adding a title quietly turns the memory into a
/// Photo, Voice or Object; nothing has to be chosen up front. The deliberate
/// modes (Let go, Ritual, Capsule) sit in a small secondary row.
class QuickCaptureSheet extends ConsumerStatefulWidget {
  final String? initialText;
  final bool startAsCapsule;

  const QuickCaptureSheet({
    super.key,
    this.initialText,
    this.startAsCapsule = false,
  });

  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  /// How long the mic must be held before recording starts; a shorter press
  /// just opens the recorder.
  static const _holdToRecordDelay = Duration(milliseconds: 220);

  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _voiceKey = GlobalKey<VoiceCaptureContentState>();

  /// Let go or Ritual, when chosen. Everything else is inferred.
  EntryType? _explicitType;
  bool _showTitle = false;
  bool _isSaving = false;
  bool _wasExplicitlySaved = false;
  Future<bool>? _saveFuture;
  bool _didPopDuringSave = false;
  String? _saveError;

  // Attachments
  String? _photoPath;
  bool _isPickingPhoto = false;
  bool _voiceOpen = false;
  String? _voicePath;
  Duration? _voiceDuration;

  /// A memory holds one photo or one voice memo. Set when the person agreed
  /// to swap their photo for a voice memo: the photo goes only once the
  /// recording exists to take its place.
  bool _voiceReplacesPhoto = false;

  // Hold-to-record from the toolbar mic
  Timer? _holdTimer;
  Offset? _holdOrigin;
  bool _holdStarted = false;
  bool _voiceWasOpenOnDown = false;

  /// The inline Camera / Library choice under the field.
  bool _photoSourceOpen = false;

  /// The second row of quiet buttons (Let go, Ritual, Capsule).
  bool _modesOpen = false;

  /// When the memory happened, if the person moved it. Null means now.
  DateTime? _createdAt;

  // Capsule capture state
  bool _sealAsCapsule = false;
  DateTime? _capsuleUnlockDate;

  // Swipe down to save: how far the sheet has been dragged so far.
  double _dragOffset = 0;
  bool _dismissInFlight = false;

  /// A downward fling faster than this (logical px/s) dismisses the sheet.
  static const _dismissVelocity = 700.0;

  /// A drag further than this (logical px) dismisses the sheet on release.
  static const _dismissDistance = 100.0;

  // Media captured into this draft; files not saved are deleted.
  late final DraftMediaTracker _draftMedia = DraftMediaTracker(
    () => ref.read(fileStorageServiceProvider).deleteFile,
  );

  @override
  void initState() {
    super.initState();
    _sealAsCapsule = widget.startAsCapsule;
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    // Open straight into writing: keyboard up, nothing to choose first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _releaseUnsavedMedia();
    _textController.dispose();
    _focusNode.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  /// Deletes media captured into a draft that was never saved. If a save is
  /// still in flight, waits for it so a file that is being saved survives.
  void _releaseUnsavedMedia() {
    final pendingSave = _saveFuture;
    if (pendingSave != null) {
      unawaited(
        pendingSave.then((saved) {
          if (!saved) return _draftMedia.discard();
        }),
      );
    } else if (!_wasExplicitlySaved) {
      unawaited(_draftMedia.discard());
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Inference
  // ───────────────────────────────────────────────────────────────────────

  EntryType get _inferredType => inferCaptureType(
    text: _textController.text,
    title: _showTitle ? _titleController.text : '',
    hasPhoto: _photoPath != null,
    hasVoice: _voicePath != null,
    explicit: _explicitType,
  );

  bool get _isDeliberateMode =>
      _explicitType == EntryType.release || _explicitType == EntryType.ritual;

  bool get _hasAttachments => _photoPath != null || _voicePath != null;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Duration _motion(int ms) =>
      _reduceMotion ? Duration.zero : Duration(milliseconds: ms);

  // ───────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final mutedText = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary);

    final content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!mounted) return;
        if (didPop) {
          // Something closed the route without asking (a pop from outside
          // the sheet). Keep whatever can be kept; the save holds its own
          // references, so it finishes even as the sheet goes away.
          if (!_wasExplicitlySaved && _canSave()) {
            unawaited(_saveEntry(fromDismiss: true));
          }
          return;
        }
        unawaited(_dismiss());
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle: swipe down to save and close.
            ExcludeSemantics(
              child: SizedBox(
                key: const ValueKey('capture-drag-handle'),
                width: double.infinity,
                height: 24,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PlatformUtils.isIOS
                          ? CupertinoColors.systemGrey3
                          : context.palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            // Compression / save progress hairline
            AnimatedSwitcher(
              duration: _motion(220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: _isSaving
                  ? const _SaveHairline(key: ValueKey('saving'))
                  : const SizedBox(
                      key: ValueKey('idle'),
                      height: 2,
                      width: double.infinity,
                    ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSize(
                duration: _motion(220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showTitle) ...[
                      _buildTitleField(),
                      const SizedBox(height: 10),
                    ],
                    if (_photoPath != null) ...[
                      _buildPhotoPreview(),
                      const SizedBox(height: 12),
                    ],
                    if (_voiceOpen) ...[
                      VoiceCaptureContent(
                        key: _voiceKey,
                        initialVoicePath: _voicePath,
                        initialDuration: _voiceDuration,
                        text: '',
                        showNoteField: false,
                        onVoicePathChanged: _onVoicePathChanged,
                        onDurationChanged: (duration) =>
                            _voiceDuration = duration,
                        onTextChanged: (_) {},
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildTextField(),
                    if (!_sealAsCapsule) ...[
                      const SizedBox(height: 6),
                      _buildWhenLine(),
                    ],
                    if (_photoSourceOpen) ...[
                      const SizedBox(height: 12),
                      _buildPhotoSourceRow(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Attachments + the few deliberate modes: one row of quiet
            // buttons, the deliberate ones folded under "More".
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildToolbar(),
            ),
            if (_sealAsCapsule) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCapsuleControls(),
              ),
            ],
            const SizedBox(height: 16),
            if (_saveError != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.palette.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AdaptiveIcons.error,
                        size: 18,
                        color: context.palette.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.palette.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Save hint and save button row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _canSave() ? _readyLabel() : _getSaveHint(),
                      style: mutedText,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    enabled: _canSave(),
                    label: _sealAsCapsule
                        ? 'Seal and save as capsule'
                        : 'Save memory',
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      minimumSize: const Size(44, 44),
                      color: _canSave()
                          ? context.palette.primaryFill
                          : context.palette.surfaceMuted,
                      borderRadius: SeedlingRadius.button,
                      onPressed: _canSave()
                          ? () {
                              HapticFeedback.selectionClick();
                              if (_saveError != null) {
                                setState(() => _saveError = null);
                              }
                              _saveEntry();
                            }
                          : null,
                      child: Text(
                        _sealAsCapsule ? 'Seal capsule' : 'Save memory',
                        style: TextStyle(
                          color: _canSave()
                              ? context.palette.onPrimaryFill
                              : context.palette.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );

    // Wrap with glass effect on iOS. The sheet follows the finger on a
    // downward drag; letting go far or fast enough saves and closes it.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onSheetDragUpdate,
      onVerticalDragEnd: _onSheetDragEnd,
      onVerticalDragCancel: _resetSheetDrag,
      child: AnimatedContainer(
        duration: _dragOffset == 0 ? _motion(200) : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: GlassSheet(
          backgroundColor: context.palette.surface,
          opacity: PlatformUtils.isIOS ? 0.85 : 1.0,
          child: content,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Swipe down to save
  // ───────────────────────────────────────────────────────────────────────

  void _onSheetDragUpdate(DragUpdateDetails details) {
    if (_dismissInFlight) return;
    final next = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
    if (next != _dragOffset) setState(() => _dragOffset = next);
  }

  void _onSheetDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dismiss =
        velocity > _dismissVelocity ||
        (_dragOffset > _dismissDistance && velocity >= 0);
    _resetSheetDrag();
    if (dismiss) unawaited(_dismiss());
  }

  void _resetSheetDrag() {
    if (_dragOffset != 0 && mounted) setState(() => _dragOffset = 0);
  }

  /// The one way the sheet closes itself when asked to (swipe down, back,
  /// tapping outside): saves a savable draft exactly once, asks before
  /// throwing away an incomplete one, and closes an empty one quietly.
  Future<void> _dismiss() async {
    if (_dismissInFlight || !mounted) return;
    _dismissInFlight = true;
    try {
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      final shouldPop = await _handleRouteDismiss();
      if (!mounted) return;
      final routeIsCurrent = route?.isCurrent ?? false;
      if (shouldPop && navigator.mounted && routeIsCurrent) {
        navigator.pop();
      }
    } finally {
      _dismissInFlight = false;
    }
  }

  /// The page: no box, large comfortable type.
  static const _fieldFontSize = 20.0;
  static const _fieldLineHeight = 1.4;

  TextStyle _fieldStyle() => TextStyle(
    fontSize: _fieldFontSize,
    height: _fieldLineHeight,
    color: context.palette.textPrimary,
    letterSpacing: -0.1,
  );

  /// The longest of the candidate hints that fits in two lines at [width]:
  /// the person's own cue plus the question, then the cue alone, then the
  /// plain question. Never cut mid-word.
  String _fittingHint(String hint, double width) {
    final candidates = <String>[hint];
    const suffix = '… what stayed with you?';
    if (hint.endsWith(suffix)) {
      candidates.add('${hint.substring(0, hint.length - suffix.length)}…');
    }
    candidates.add(captureHintFor(null));
    final textScaler = MediaQuery.textScalerOf(context);
    for (final candidate in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: _fieldStyle()),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 2,
      )..layout(maxWidth: width);
      final fits = !painter.didExceedMaxLines;
      painter.dispose();
      if (fits) return candidate;
    }
    return candidates.last;
  }

  Widget _buildTextField() {
    final rawHint = _getHintText();
    return LayoutBuilder(
      builder: (context, constraints) {
        final hint = _fittingHint(rawHint, constraints.maxWidth);
        final style = _fieldStyle();
        final hintColor = context.palette.textMuted;
        if (PlatformUtils.isIOS) {
          return CupertinoTextField(
            key: const ValueKey('capture-text'),
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 8,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            placeholder: hint,
            placeholderStyle: style.copyWith(color: hintColor),
            style: style,
            cursorColor: context.palette.primary,
            decoration: const BoxDecoration(color: Colors.transparent),
            padding: EdgeInsets.zero,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _saveEntry(),
          );
        }

        return TextField(
          key: const ValueKey('capture-text'),
          controller: _textController,
          focusNode: _focusNode,
          maxLines: 8,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: style,
          cursorColor: context.palette.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintMaxLines: 2,
            hintStyle: style.copyWith(color: hintColor),
            // A page, not a form field: the theme's outlined borders and
            // fill are switched off.
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveEntry(),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // When it happened
  // ───────────────────────────────────────────────────────────────────────

  String _whenLabel(DateTime at) => DateLabels.dayWithTimeOf(context, at);

  Widget _buildWhenLine() {
    final at = _createdAt ?? DateTime.now();
    final palette = context.palette;
    final moved = _createdAt != null;
    final label = _whenLabel(at);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'When: $label',
        hint: 'Change when this happened',
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('capture-when'),
          behavior: HitTestBehavior.opaque,
          onTap: _pickWhen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PlatformUtils.isIOS ? CupertinoIcons.clock : Icons.schedule,
                  size: 15,
                  color: moved ? palette.primary : palette.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: moved ? palette.primary : palette.textSecondary,
                    fontWeight: moved ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Backdates the memory. Optional; never in the future.
  Future<void> _pickWhen() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _createdAt ?? now;
    final first = DateTime(1900);

    if (PlatformUtils.isIOS) {
      var selected = initial;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () {
                        setState(() => _createdAt = null);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Now'),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        final future = selected.isAfter(DateTime.now());
                        setState(() => _createdAt = future ? null : selected);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    minimumDate: first,
                    maximumDate: now,
                    initialDateTime: initial,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now,
      initialDate: initial,
      helpText: 'When did this happen?',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(initial);
    var picked = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    if (picked.isAfter(DateTime.now())) picked = DateTime.now();
    final isNow = DateTime.now().difference(picked).inMinutes.abs() < 1;
    setState(() => _createdAt = isNow ? null : picked);
  }

  Widget _buildTitleField() {
    final isRitual = _explicitType == EntryType.ritual;
    final hint = isRitual
        ? 'Name this ritual, e.g. Sunday pancakes'
        : 'Give it a name, e.g. Grandma\'s ring';
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final field = PlatformUtils.isIOS
        ? CupertinoTextField(
            key: const ValueKey('capture-title'),
            controller: _titleController,
            focusNode: _titleFocusNode,
            textCapitalization: TextCapitalization.sentences,
            placeholder: hint,
            placeholderStyle: TextStyle(
              color: CupertinoColors.placeholderText,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            style: style,
            decoration: const BoxDecoration(color: Colors.transparent),
            padding: EdgeInsets.zero,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _focusNode.requestFocus(),
          )
        : TextField(
            key: const ValueKey('capture-title'),
            controller: _titleController,
            focusNode: _titleFocusNode,
            textCapitalization: TextCapitalization.sentences,
            style: style,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: style?.copyWith(color: context.palette.textMuted),
              border: InputBorder.none,
              filled: false,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _focusNode.requestFocus(),
          );
    return Semantics(
      textField: true,
      label: isRitual ? 'Ritual name' : 'Title',
      child: field,
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: SeedlingRadius.card,
          child: Image.file(
            File(_photoPath!),
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Attached photo',
            errorBuilder: (_, _, _) => Container(
              height: 150,
              color: context.palette.accentPhoto.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(
                AdaptiveIcons.photo,
                color: context.palette.accentPhoto,
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Semantics(
            button: true,
            label: 'Remove photo',
            child: GestureDetector(
              onTap: _removePhoto,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.palette.mediaScrim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PlatformUtils.isIOS ? CupertinoIcons.xmark : Icons.close,
                  color: context.palette.onMedia,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onVoicePathChanged(String? path) {
    unawaited(_draftMedia.update(previous: _voicePath, next: path));
    final replacePhoto =
        path != null && _voiceReplacesPhoto && _photoPath != null;
    if (replacePhoto) {
      // The person asked for this swap; the recording now takes its place.
      unawaited(_draftMedia.update(previous: _photoPath));
    }
    setState(() {
      _voicePath = path;
      if (replacePhoto) _photoPath = null;
      if (path != null) _voiceReplacesPhoto = false;
    });
  }

  /// Asks before one kind of attachment replaces the other. A memory holds
  /// one photo or one voice memo, and nothing the person can still see is
  /// ever dropped without them saying so.
  Future<bool> _confirmReplaceAttachment({
    required String title,
    required String keepLabel,
  }) async {
    const message =
        'A memory holds one photo or one voice memo. '
        'The one you have now will be removed.';
    if (PlatformUtils.isIOS) {
      final replace = await showCupertinoModalPopup<bool>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: Text(title),
          message: const Text(message),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('Replace'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text(keepLabel),
          ),
        ),
      );
      return replace ?? false;
    }
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(keepLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return replace ?? false;
  }

  Future<void> _askVoiceReplacesPhoto() async {
    final replace = await _confirmReplaceAttachment(
      title: 'Replace the photo with a voice memo?',
      keepLabel: 'Keep photo',
    );
    if (!replace || !mounted) return;
    _focusNode.unfocus();
    _titleFocusNode.unfocus();
    setState(() {
      _voiceReplacesPhoto = true;
      _voiceOpen = true;
    });
  }

  bool get _modesVisible => _modesOpen || _isDeliberateMode || _sealAsCapsule;

  Widget _buildToolbar() {
    final attachEnabled = !_isDeliberateMode;
    final deliberateEnabled = !_hasAttachments && !_voiceOpen;
    final palette = context.palette;
    final activeMode = _explicitType == EntryType.release
        ? palette.accentRelease
        : _explicitType == EntryType.ritual
        ? palette.accentRitual
        : _sealAsCapsule
        ? palette.accentGold
        : palette.primary;

    final attachRow = Row(
      children: [
        Expanded(
          child: _AttachButton(
            icon: AdaptiveIcons.photo,
            label: 'Photo',
            semanticLabel: _voicePath != null
                ? 'Replace the voice memo with a photo'
                : (_photoPath == null ? 'Add a photo' : 'Replace photo'),
            color: palette.accentPhoto,
            active: _photoPath != null || _photoSourceOpen,
            enabled: attachEnabled && !_isPickingPhoto,
            onTap: _attachPhoto,
          ),
        ),
        Expanded(child: _buildMicButton(enabled: attachEnabled)),
        Expanded(
          child: _AttachButton(
            icon: PlatformUtils.isIOS ? CupertinoIcons.textformat : Icons.title,
            label: 'Title',
            semanticLabel: _showTitle ? 'Remove title' : 'Add a title',
            color: _explicitType == EntryType.ritual
                ? palette.accentRitual
                : palette.accentObject,
            active: _showTitle,
            enabled:
                _explicitType != EntryType.ritual &&
                _explicitType != EntryType.release,
            onTap: _toggleTitle,
          ),
        ),
        Expanded(
          child: _AttachButton(
            key: const ValueKey('capture-more'),
            icon: PlatformUtils.isIOS
                ? CupertinoIcons.ellipsis
                : Icons.more_horiz,
            label: 'More',
            semanticLabel: _modesVisible
                ? 'Hide Let go, Ritual and Capsule'
                : 'More: Let go, Ritual, Capsule',
            color: activeMode,
            active: _modesVisible,
            enabled: true,
            onTap: () => setState(() {
              // A chosen mode keeps its row open; "More" then just stays lit.
              _modesOpen = !_modesOpen;
            }),
          ),
        ),
      ],
    );

    final modesRow = Row(
      children: [
        Expanded(
          child: _AttachButton(
            icon: AdaptiveIcons.wind,
            label: 'Let go',
            semanticLabel: 'Let go mode',
            hint: 'For releasing something you want to leave behind',
            color: palette.accentRelease,
            active: _explicitType == EntryType.release,
            enabled: deliberateEnabled,
            onTap: () => _toggleExplicit(EntryType.release),
          ),
        ),
        Expanded(
          child: _AttachButton(
            icon: PlatformUtils.isIOS ? CupertinoIcons.repeat : Icons.repeat,
            label: 'Ritual',
            semanticLabel: 'Ritual mode',
            hint: 'For a moment that keeps coming back',
            color: palette.accentRitual,
            active: _explicitType == EntryType.ritual,
            enabled: deliberateEnabled,
            onTap: () => _toggleExplicit(EntryType.ritual),
          ),
        ),
        Expanded(
          child: _AttachButton(
            icon: CupertinoIcons.lock_shield,
            label: 'Capsule',
            semanticLabel: _sealAsCapsule
                ? 'Capsule mode enabled'
                : 'Enable capsule mode',
            hint: 'Adds an unlock date before this memory can be opened',
            color: palette.accentGold,
            active: _sealAsCapsule,
            enabled: true,
            onTap: () {
              setState(() {
                _sealAsCapsule = !_sealAsCapsule;
                if (!_sealAsCapsule) _capsuleUnlockDate = null;
              });
            },
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );

    return AnimatedSize(
      duration: _motion(200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          attachRow,
          if (_modesVisible) ...[const SizedBox(height: 4), modesRow],
        ],
      ),
    );
  }

  /// The mic: a short tap opens the recorder, holding it records straight
  /// away (lift to stop). A raw [Listener] so the hold keeps working while
  /// the recorder appears above it.
  Widget _buildMicButton({required bool enabled}) {
    if (_photoPath != null && !_voiceReplacesPhoto) {
      // Holding would record over the photo; ask first instead.
      return _AttachButton(
        icon: AdaptiveIcons.mic,
        label: 'Voice',
        semanticLabel: 'Replace the photo with a voice memo',
        color: context.palette.accentVoice,
        active: false,
        enabled: enabled,
        onTap: _askVoiceReplacesPhoto,
      );
    }
    final active = _voiceOpen || _voicePath != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: _voicePath != null
          ? 'Voice memo attached'
          : (_voiceOpen ? 'Close voice recorder' : 'Record a voice memo'),
      hint: 'Hold to record',
      onTap: enabled ? _toggleVoicePanel : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: enabled ? _onMicDown : null,
        onPointerMove: enabled ? _onMicMove : null,
        onPointerUp: enabled ? _onMicUp : null,
        onPointerCancel: enabled ? (_) => _onMicUp(null) : null,
        child: _AttachButtonFace(
          icon: AdaptiveIcons.mic,
          label: 'Voice',
          color: context.palette.accentVoice,
          active: active,
          enabled: enabled,
        ),
      ),
    );
  }

  void _onMicDown(PointerDownEvent event) {
    _voiceWasOpenOnDown = _voiceOpen;
    _holdOrigin = event.position;
    _holdStarted = false;
    if (!_voiceOpen) {
      HapticFeedback.selectionClick();
      _focusNode.unfocus();
      _titleFocusNode.unfocus();
      setState(() => _voiceOpen = true);
    }
    _holdTimer?.cancel();
    if (_voicePath != null) return; // Already recorded; nothing to hold for.
    _holdTimer = Timer(_holdToRecordDelay, () {
      if (!mounted) return;
      _holdStarted = true;
      unawaited(_voiceKey.currentState?.beginHold());
    });
  }

  void _onMicMove(PointerMoveEvent event) {
    final origin = _holdOrigin;
    if (origin == null || !(_holdTimer?.isActive ?? false)) return;
    if ((event.position - origin).distance > 18) {
      // The finger is scrolling the row, not holding the mic.
      _holdTimer?.cancel();
    }
  }

  void _onMicUp(PointerEvent? _) {
    _holdOrigin = null;
    if (_holdTimer?.isActive ?? false) {
      _holdTimer!.cancel();
      // A tap: close the recorder again if it was already open and empty.
      if (_voiceWasOpenOnDown && _voicePath == null) {
        setState(() {
          _voiceOpen = false;
          _voiceReplacesPhoto = false;
        });
        _focusNode.requestFocus();
      }
      return;
    }
    if (_holdStarted) {
      _holdStarted = false;
      unawaited(_voiceKey.currentState?.endHold());
    }
  }

  void _toggleVoicePanel() {
    if (_voicePath != null) return;
    setState(() {
      _voiceOpen = !_voiceOpen;
      if (!_voiceOpen) _voiceReplacesPhoto = false;
    });
    if (_voiceOpen) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _toggleTitle() {
    setState(() {
      _showTitle = !_showTitle;
      if (!_showTitle) _titleController.clear();
    });
    if (_showTitle) {
      _titleFocusNode.requestFocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _toggleExplicit(EntryType type) {
    setState(() {
      if (_explicitType == type) {
        _explicitType = null;
        if (type == EntryType.ritual) {
          _showTitle = _titleController.text.trim().isNotEmpty;
        }
      } else {
        _explicitType = type;
        if (type == EntryType.ritual) {
          _showTitle = true;
        } else if (type == EntryType.release) {
          // Letting go is words only.
          _showTitle = false;
          _titleController.clear();
        }
      }
    });
    if (_explicitType == EntryType.ritual &&
        _titleController.text.trim().isEmpty) {
      _titleFocusNode.requestFocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Photo
  // ───────────────────────────────────────────────────────────────────────

  /// Camera and Library, inline under the field: two quiet tiles instead of
  /// a second sheet stacked on top of this one.
  Widget _buildPhotoSourceRow() {
    final palette = context.palette;
    Widget tile(_PhotoSource source, IconData icon, String label) {
      return Expanded(
        child: Semantics(
          button: true,
          label: source == _PhotoSource.camera
              ? 'Take a photo'
              : 'Choose from library',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              unawaited(_pickPhoto(source));
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.accentPhoto.withValues(alpha: 0.10),
                borderRadius: SeedlingRadius.small,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: palette.inkFor(palette.accentPhoto),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: palette.inkFor(palette.accentPhoto),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      key: const ValueKey('capture-photo-source'),
      children: [
        tile(
          _PhotoSource.camera,
          PlatformUtils.isIOS
              ? CupertinoIcons.camera
              : Icons.camera_alt_outlined,
          'Camera',
        ),
        const SizedBox(width: 10),
        tile(
          _PhotoSource.library,
          PlatformUtils.isIOS
              ? CupertinoIcons.photo_on_rectangle
              : Icons.photo_library_outlined,
          'Library',
        ),
      ],
    );
  }

  Future<void> _attachPhoto() async {
    if (_isPickingPhoto) return;
    if (_photoSourceOpen) {
      setState(() => _photoSourceOpen = false);
      return;
    }
    // A memory holds one photo or one voice memo: ask before a photo takes
    // the place of a recording. The recording stays until a photo arrives.
    if (_voicePath != null) {
      final replace = await _confirmReplaceAttachment(
        title: 'Replace the voice memo with a photo?',
        keepLabel: 'Keep voice memo',
      );
      if (!replace || !mounted) return;
    } else if (_voiceOpen) {
      // An empty recorder: nothing to lose, just put it away.
      setState(() {
        _voiceOpen = false;
        _voiceReplacesPhoto = false;
      });
    }
    setState(() => _photoSourceOpen = true);
  }

  Future<void> _pickPhoto(_PhotoSource source) async {
    if (_isPickingPhoto) return;
    final replacesVoice = _voicePath != null;
    setState(() {
      _photoSourceOpen = false;
      _isPickingPhoto = true;
    });
    final service = ref.read(photoCaptureServiceProvider);
    final PhotoCaptureResult result;
    try {
      result = source == _PhotoSource.camera
          ? await service.captureFromCamera()
          : await service.pickFromGallery();
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
    if (!mounted) return;

    if (result.isSuccess && result.path != null) {
      HapticFeedback.lightImpact();
      unawaited(_draftMedia.update(previous: _photoPath, next: result.path));
      final replacedVoice = replacesVoice ? _voicePath : null;
      if (replacedVoice != null) {
        unawaited(_draftMedia.update(previous: replacedVoice));
      }
      setState(() {
        _photoPath = result.path;
        if (replacedVoice != null) {
          _voicePath = null;
          _voiceDuration = null;
          _voiceOpen = false;
        }
      });
      _focusNode.requestFocus();
    } else if (result.permissionDenied) {
      final camera = source == _PhotoSource.camera;
      await _showPermissionDenied(
        permission: camera ? Permission.camera : Permission.photos,
        permissionName: camera ? 'Camera' : 'Photos',
        purpose: camera
            ? 'capture photo memories'
            : 'pick images from your library',
      );
    } else if (result.error != null) {
      showSeedlingMessage(context, result.error!);
    }
  }

  void _removePhoto() {
    HapticFeedback.selectionClick();
    unawaited(_draftMedia.update(previous: _photoPath));
    setState(() => _photoPath = null);
  }

  Future<void> _showPermissionDenied({
    required Permission permission,
    required String permissionName,
    required String purpose,
  }) async {
    final permissionService = ref.read(permissionServiceProvider);
    final shouldOpenSettings = await permissionService.shouldOpenSettingsFor(
      permission,
    );
    if (!mounted) return;
    if (shouldOpenSettings) {
      await permissionService.showPermissionDeniedDialog(
        context,
        permissionName: permissionName,
        purpose: purpose,
      );
      return;
    }
    showSeedlingMessage(context, '$permissionName permission was denied');
  }

  // ───────────────────────────────────────────────────────────────────────
  // Capsule
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildCapsuleControls() {
    final selectedDate = _capsuleUnlockDate;
    final textColor = context.palette.textPrimary;
    final accent = context.palette.accentGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.lock_shield, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'Sealed capsule',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCapsuleDateChip(
                label: '1 month',
                onTap: () => setState(
                  () => _capsuleUnlockDate = DateTime.now().add(
                    const Duration(days: 30),
                  ),
                ),
                active: _isDateWithinDays(30),
              ),
              const SizedBox(width: 8),
              _buildCapsuleDateChip(
                label: '1 year',
                onTap: () => setState(
                  () => _capsuleUnlockDate = DateTime.now().add(
                    const Duration(days: 365),
                  ),
                ),
                active: _isDateWithinDays(365),
              ),
              const SizedBox(width: 8),
              _buildCapsuleDateChip(
                label: 'Custom',
                onTap: _pickCapsuleDate,
                active:
                    selectedDate != null &&
                    !_isDateWithinDays(30) &&
                    !_isDateWithinDays(365),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedDate == null
                ? 'Choose when this memory unlocks'
                : 'Unlocks on ${_formatCapsuleDate(selectedDate)}',
            style: TextStyle(
              color: selectedDate == null
                  ? context.palette.textSecondary
                  : context.palette.inkFor(accent),
              fontSize: 12,
              fontWeight: selectedDate == null
                  ? FontWeight.w400
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleDateChip({
    required String label,
    required VoidCallback onTap,
    required bool active,
  }) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Capsule unlock $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _motion(180),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? context.palette.accentGold.withValues(alpha: 0.2)
                : context.palette.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? context.palette.accentGold
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: active
                  ? context.palette.inkFor(context.palette.accentGold)
                  : context.palette.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isDateWithinDays(int days) {
    if (_capsuleUnlockDate == null) return false;
    final target = DateTime.now().add(Duration(days: days));
    final selected = _capsuleUnlockDate!;
    return selected.year == target.year &&
        selected.month == target.month &&
        selected.day == target.day;
  }

  Future<void> _pickCapsuleDate() async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(const Duration(days: 3650));

    if (PlatformUtils.isIOS) {
      DateTime selected = _capsuleUnlockDate ?? firstDate;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () {
                    setState(() => _capsuleUnlockDate = selected);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  initialDateTime: selected,
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: _capsuleUnlockDate ?? firstDate,
    );
    if (picked != null) {
      setState(() => _capsuleUnlockDate = picked);
    }
  }

  String _formatCapsuleDate(DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMd(locale).format(date);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Copy
  // ───────────────────────────────────────────────────────────────────────

  String _getHintText() {
    if (_explicitType == EntryType.release) {
      return 'What would you like to let go of?';
    }
    if (_explicitType == EntryType.ritual) {
      return 'What happens, and what it means (optional)';
    }
    if (_voicePath != null || _photoPath != null) {
      return 'Add a note (optional)';
    }
    if (_showTitle) return 'Its story (optional)';
    return captureHintFor(ref.watch(captureIntentionProvider));
  }

  String _readyLabel() {
    if (_sealAsCapsule) return 'Ready to seal';
    return switch (_inferredType) {
      EntryType.photo => 'A photo memory',
      EntryType.voice => 'A voice memory',
      EntryType.object => 'Saving as an object',
      EntryType.ritual => 'Saving as a ritual',
      EntryType.release => 'Ready to let go',
      _ => 'Ready to save',
    };
  }

  String _getSaveHint() {
    if (_sealAsCapsule && _capsuleUnlockDate == null) {
      return 'Pick an unlock date';
    }
    if (_explicitType == EntryType.ritual) return 'Name the ritual';
    if (_voiceOpen && _voicePath == null) {
      return 'Hold the mic to record';
    }
    return 'Swipe down to save';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Saving
  // ───────────────────────────────────────────────────────────────────────

  bool _canSave() {
    final requiresCapsuleDate = _sealAsCapsule && _capsuleUnlockDate == null;
    if (requiresCapsuleDate) return false;

    final text = _textController.text.trim();
    final title = _titleController.text.trim();
    return switch (_inferredType) {
      EntryType.photo => _photoPath != null,
      EntryType.voice => _voicePath != null,
      EntryType.object => title.isNotEmpty,
      EntryType.ritual => title.isNotEmpty,
      _ => text.isNotEmpty,
    };
  }

  Future<bool> _saveEntry({bool fromDismiss = false}) {
    if (_saveFuture != null) {
      return _saveFuture!;
    }

    final saveFuture = _performSaveEntry(fromDismiss: fromDismiss);
    _saveFuture = saveFuture;
    return saveFuture.whenComplete(() => _saveFuture = null);
  }

  /// Translate sheet state into a [CaptureIntent]. Returns null when the
  /// current draft has nothing to save (e.g. an object with no title).
  CaptureIntent? _buildIntent() {
    final capsuleUnlockDate = _sealAsCapsule ? _capsuleUnlockDate : null;
    String? nullIfEmpty(String value) => value.isEmpty ? null : value;
    final text = _textController.text.trim();
    final title = _titleController.text.trim();

    switch (_inferredType) {
      case EntryType.release:
        return ReleaseCapture(
          nullIfEmpty(text),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      case EntryType.ritual:
        if (title.isEmpty) return null;
        return RitualCapture(
          title: title,
          text: nullIfEmpty(text),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      case EntryType.voice:
        if (_voicePath == null) return null;
        return VoiceCapture(
          mediaPath: _voicePath!,
          text: nullIfEmpty(text),
          title: nullIfEmpty(title),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      case EntryType.object:
        if (title.isEmpty) return null;
        return ObjectCapture(
          title: title,
          mediaPath: _photoPath,
          text: nullIfEmpty(text),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      case EntryType.photo:
        if (_photoPath == null) return null;
        return PhotoCapture(
          mediaPath: _photoPath!,
          text: nullIfEmpty(text),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      case EntryType.fragment:
        return FragmentCapture(
          nullIfEmpty(text),
          capsuleUnlockDate: capsuleUnlockDate,
        );
      default:
        return LineCapture(text, capsuleUnlockDate: capsuleUnlockDate);
    }
  }

  static String? _mediaPathOf(CaptureIntent? intent) => switch (intent) {
    PhotoCapture(:final mediaPath) => mediaPath,
    VoiceCapture(:final mediaPath) => mediaPath,
    ObjectCapture(:final mediaPath) => mediaPath,
    _ => null,
  };

  Future<bool> _performSaveEntry({bool fromDismiss = false}) async {
    // Bulletproof: if already explicitly saved, never save again
    if (_wasExplicitlySaved) return true;

    if (!_canSave()) {
      return false;
    }

    if (_isSaving) {
      return false;
    }
    if (mounted) {
      setState(() => _isSaving = true);
    } else {
      _isSaving = true;
    }
    _didPopDuringSave = false;

    // Read everything the save needs up front: a swipe can close the sheet
    // while the save is still running, and ref is gone after dispose.
    final errorReporter = ref.read(errorReporterProvider);
    final Entry saved;
    final CaptureIntent? intent;
    final EntryCreatorNotifier creator;
    try {
      creator = ref.read(entryCreatorProvider.notifier);
      intent = _buildIntent();
      if (intent == null) {
        _setNotSaving();
        return false;
      }
      saved = await creator.create(
        intent,
        createdAt: _sealAsCapsule ? null : _createdAt,
      );
    } catch (e, st) {
      errorReporter.report(
        e,
        stack: st,
        context: 'QuickCaptureSheet._saveEntry',
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          if (!fromDismiss) {
            _saveError = 'Could not save this memory. Please try again.';
          }
        });
      } else {
        _isSaving = false;
      }
      return false;
    }

    // The entry exists now. From here on nothing may undo that: mark it
    // saved first (no second save, no discard on close) and keep its file.
    _wasExplicitlySaved = true;
    unawaited(_draftMedia.commit(_mediaPathOf(intent)));

    try {
      if (saved.type == EntryType.release && !saved.isCapsule && mounted) {
        _offerReleaseCeremony(saved, creator);
      }
      if (_sealAsCapsule) {
        await HapticService.onCapsuleCreated();
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    } catch (e, st) {
      errorReporter.report(
        e,
        stack: st,
        context: 'QuickCaptureSheet._saveEntry (after save)',
      );
    }

    _setNotSaving();
    if (!fromDismiss && mounted) {
      _didPopDuringSave = true;
      Navigator.of(context).pop();
    }
    return true;
  }

  void _setNotSaving() {
    if (mounted) {
      setState(() => _isSaving = false);
    } else {
      _isSaving = false;
    }
  }

  /// Once this sheet has closed, plays the letting-go ceremony for a saved
  /// Release entry and offers to delete it for good.
  void _offerReleaseCeremony(Entry saved, EntryCreatorNotifier creator) {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null) return;
    final entryId = saved.id;
    final text = saved.text;
    unawaited(
      route.popped.then((_) async {
        if (!navigator.mounted) return;
        await showReleaseCeremony(
          navigator,
          text: text,
          onLetGo: () async {
            final removed = await creator.permanentlyDeleteEntry(entryId);
            if (!removed) throw StateError('Release entry was not deleted');
          },
        );
      }),
    );
  }

  bool _hasDraftContent() {
    return _textController.text.trim().isNotEmpty ||
        _titleController.text.trim().isNotEmpty ||
        _photoPath != null ||
        _voicePath != null;
  }

  Future<bool> _handleRouteDismiss() async {
    if (_wasExplicitlySaved || !_hasDraftContent()) {
      return !_wasExplicitlySaved;
    }
    if (_saveFuture != null) {
      final didSave = await _saveFuture!;
      return didSave && !_didPopDuringSave;
    }
    if (!_canSave()) {
      return _confirmDiscardDraft();
    }
    return await _saveEntry(fromDismiss: true);
  }

  Future<bool> _confirmDiscardDraft() async {
    if (!mounted) return false;

    if (PlatformUtils.isIOS) {
      final shouldDiscard = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Discard draft?'),
          content: const Text(
            'This memory is incomplete and will not be saved if you close it now.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text(
          'This memory is incomplete and will not be saved if you close it now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }
}

enum _PhotoSource { camera, library }

/// Small icon-over-label face shared by the attachment buttons.
class _AttachButtonFace extends StatelessWidget {
  const _AttachButtonFace({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final palette = context.palette;
    final tint = active ? color : palette.textSecondary;
    final labelColor = active ? palette.inkFor(color) : palette.textSecondary;
    return AnimatedOpacity(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.35,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: tint),
            const SizedBox(height: 2),
            // Shrinks rather than clips on narrow screens or large text.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.active,
    required this.enabled,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final String? hint;
  final Color color;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handleTap = enabled
        ? () {
            HapticFeedback.selectionClick();
            onTap();
          }
        : null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: semanticLabel,
      hint: hint,
      onTap: handleTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: _AttachButtonFace(
          icon: icon,
          label: label,
          color: color,
          active: active,
          enabled: enabled,
        ),
      ),
    );
  }
}

/// Indeterminate hairline shown above the sheet content while saving.
class _SaveHairline extends StatelessWidget {
  const _SaveHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      width: double.infinity,
      child: LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(context.palette.primary),
      ),
    );
  }
}
