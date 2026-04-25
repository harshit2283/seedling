import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/colors.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../data/models/entry.dart';
import 'widgets/entry_type_button.dart';
import 'widgets/object_capture_content.dart';
import 'widgets/photo_capture_content.dart';
import 'widgets/voice_capture_content.dart';

/// Capture mode for the sheet
enum CaptureMode {
  text, // Line, Fragment, Release
  photo, // Photo capture
  voice, // Voice recording
  object, // Object with title
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
      builder: (context) => QuickCaptureSheet(
        initialText: initialText,
        startAsCapsule: startAsCapsule,
      ),
    );
  }
}

/// Quick capture bottom sheet for adding memories
/// Philosophy: Capture should feel like breathing, not documenting
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
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  EntryType _selectedType = EntryType.line;
  CaptureMode _captureMode = CaptureMode.text;
  bool _isSaving = false;
  bool _wasExplicitlySaved = false;
  Future<bool>? _saveFuture;
  bool _didPopDuringSave = false;
  String? _saveError;

  // Photo capture state
  String? _photoPath;
  String _photoText = '';

  // Voice capture state
  String? _voicePath;
  Duration? _voiceDuration;
  String _voiceText = '';

  // Object capture state
  String? _objectPhotoPath;
  String _objectTitle = '';
  String _objectStory = '';

  // Capsule capture state
  bool _sealAsCapsule = false;
  DateTime? _capsuleUnlockDate;

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
    // Auto-focus the text field for text mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_captureMode == CaptureMode.text) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    final content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !mounted) return;
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        final shouldPop = await _handleRouteDismiss();
        if (!mounted) return;
        final routeIsCurrent = route?.isCurrent ?? false;
        if (shouldPop && navigator.mounted && routeIsCurrent) {
          navigator.pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (decorative)
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PlatformUtils.isIOS
                      ? CupertinoColors.systemGrey3
                      : SeedlingColors.lightBark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Main content area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildContentArea(),
            ),
            const SizedBox(height: 16),
            // Entry type buttons (smart ordered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(children: _buildOrderedTypeButtons()),
              ),
            ),
            if (_sealAsCapsule) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCapsuleControls(),
              ),
            ],
            const SizedBox(height: 20),
            if (_saveError != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SeedlingColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AdaptiveIcons.error,
                        size: 18,
                        color: SeedlingColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SeedlingColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Save hint and Plant button row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _canSave() ? 'Ready to save this memory' : _getSaveHint(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SeedlingColors.textMuted,
                      ),
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
                        horizontal: 18,
                        vertical: 10,
                      ),
                      color: _canSave()
                          ? SeedlingColors.forestGreen
                          : Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(12),
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
                        _sealAsCapsule ? 'SAVE CAPSULE' : 'SAVE MEMORY',
                        style: TextStyle(
                          color: _canSave()
                              ? Colors.white
                              : SeedlingColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
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

    // Wrap with glass effect on iOS
    return GlassSheet(
      backgroundColor:
          Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      opacity: PlatformUtils.isIOS ? 0.85 : 1.0,
      child: content,
    );
  }

  Widget _buildContentArea() {
    switch (_captureMode) {
      case CaptureMode.text:
        return _buildTextField();
      case CaptureMode.photo:
        return PhotoCaptureContent(
          initialPhotoPath: _photoPath,
          text: _photoText,
          onPhotoPathChanged: (path) => setState(() => _photoPath = path),
          onTextChanged: (text) => _photoText = text,
        );
      case CaptureMode.voice:
        return VoiceCaptureContent(
          initialVoicePath: _voicePath,
          initialDuration: _voiceDuration,
          text: _voiceText,
          onVoicePathChanged: (path) => setState(() => _voicePath = path),
          onDurationChanged: (duration) => _voiceDuration = duration,
          onTextChanged: (text) => _voiceText = text,
        );
      case CaptureMode.object:
        return ObjectCaptureContent(
          initialPhotoPath: _objectPhotoPath,
          initialTitle: _objectTitle,
          initialStory: _objectStory,
          onPhotoPathChanged: (path) => setState(() => _objectPhotoPath = path),
          onTitleChanged: (title) => _objectTitle = title,
          onStoryChanged: (story) => _objectStory = story,
        );
    }
  }

  Widget _buildTextField() {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        placeholder: _getHintText(),
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        style: const TextStyle(fontSize: 16, color: SeedlingColors.textPrimary),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.zero,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _saveEntry(),
      );
    }

    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      maxLines: 4,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: _getHintText(),
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: SeedlingColors.textMuted),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _saveEntry(),
    );
  }

  Widget _buildTypeButton(
    EntryType type,
    IconData icon,
    String label,
    Color color, {
    required CaptureMode mode,
  }) {
    final isSelected =
        _selectedType == type ||
        (_captureMode == mode && mode != CaptureMode.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: EntryTypeButton(
        icon: icon,
        label: label,
        color: color,
        isSelected: isSelected,
        onTap: () => _selectType(type, mode),
      ),
    );
  }

  /// Build type buttons in smart order based on usage
  List<Widget> _buildOrderedTypeButtons() {
    final orderedTypes = ref.watch(orderedEntryTypesProvider);

    // Type definitions for building buttons
    final typeConfig = {
      'line': () => _buildTypeButton(
        EntryType.line,
        AdaptiveIcons.quote,
        'Line',
        SeedlingColors.accentLine,
        mode: CaptureMode.text,
      ),
      'fragment': () => _buildTypeButton(
        EntryType.fragment,
        AdaptiveIcons.sparkles,
        'Fragment',
        SeedlingColors.accentFragment,
        mode: CaptureMode.text,
      ),
      'photo': () => _buildTypeButton(
        EntryType.photo,
        AdaptiveIcons.photo,
        'Photo',
        SeedlingColors.accentPhoto,
        mode: CaptureMode.photo,
      ),
      'voice': () => _buildTypeButton(
        EntryType.voice,
        AdaptiveIcons.mic,
        'Voice',
        SeedlingColors.accentVoice,
        mode: CaptureMode.voice,
      ),
      'object': () => _buildTypeButton(
        EntryType.object,
        AdaptiveIcons.category,
        'Object',
        SeedlingColors.accentObject,
        mode: CaptureMode.object,
      ),
      'release': () => _buildReleaseButton(),
      'capsule': () => _buildCapsuleButton(),
    };

    return orderedTypes
        .where((type) => typeConfig.containsKey(type))
        .map((type) => typeConfig[type]!())
        .toList();
  }

  Widget _buildReleaseButton() {
    final isRelease = _selectedType == EntryType.release;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        selected: isRelease,
        label: 'Let Go mode',
        hint: 'For releasing something you want to leave behind',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedType = EntryType.release;
              _captureMode = CaptureMode.text;
            });
            _focusNode.requestFocus();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRelease
                  ? SeedlingColors.accentRelease.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRelease
                    ? SeedlingColors.accentRelease
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: isRelease ? 2 : 1,
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isRelease ? 1.0 : 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AdaptiveIcons.wind,
                    color: isRelease
                        ? SeedlingColors.accentRelease
                        : SeedlingColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let Go',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isRelease ? FontWeight.w600 : FontWeight.w400,
                      color: isRelease
                          ? SeedlingColors.accentRelease
                          : SeedlingColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleButton() {
    final isCapsule = _sealAsCapsule;
    final capsuleColor = SeedlingColors.themeGratitude;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        selected: isCapsule,
        label: isCapsule ? 'Capsule mode enabled' : 'Enable capsule mode',
        hint: 'Adds an unlock date before this memory can be opened',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _sealAsCapsule = !_sealAsCapsule;
              if (!_sealAsCapsule) {
                _capsuleUnlockDate = null;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isCapsule
                  ? capsuleColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCapsule
                    ? capsuleColor
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: isCapsule ? 2 : 1,
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCapsule ? 1.0 : 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.lock_shield,
                    size: 20,
                    color: isCapsule ? capsuleColor : SeedlingColors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capsule',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCapsule ? FontWeight.w600 : FontWeight.w400,
                      color: isCapsule
                          ? capsuleColor
                          : SeedlingColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleControls() {
    final selectedDate = _capsuleUnlockDate;
    final textColor = SeedlingColors.textPrimary;
    final accent = SeedlingColors.themeGratitude;

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
                'Sealed Capsule',
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
                label: '1 Month',
                onTap: () => setState(
                  () => _capsuleUnlockDate = DateTime.now().add(
                    const Duration(days: 30),
                  ),
                ),
                active: _isDateWithinDays(30),
              ),
              const SizedBox(width: 8),
              _buildCapsuleDateChip(
                label: '1 Year',
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
                  ? SeedlingColors.textMuted
                  : SeedlingColors.themeGratitude,
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
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? SeedlingColors.themeGratitude.withValues(alpha: 0.2)
                : Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? SeedlingColors.themeGratitude
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active
                  ? SeedlingColors.themeGratitude
                  : SeedlingColors.textSecondary,
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

  void _selectType(EntryType type, CaptureMode mode) {
    setState(() {
      _selectedType = type;
      _captureMode = mode;
    });

    if (mode == CaptureMode.text) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
  }

  String _getHintText() {
    switch (_selectedType) {
      case EntryType.line:
        return 'What stayed with you today?';
      case EntryType.fragment:
        return 'A thought, incomplete is fine...';
      case EntryType.release:
        return 'What would you like to let go of?';
      default:
        return 'Capture a moment...';
    }
  }

  String _getSaveHint() {
    if (_sealAsCapsule && _capsuleUnlockDate == null) {
      return 'Select an unlock date to save';
    }

    if (!_canSave()) {
      return switch (_captureMode) {
        CaptureMode.text => _getHintText(),
        CaptureMode.photo =>
          _photoPath == null
              ? 'Take or choose a photo'
              : 'Add a note if you want, then save',
        CaptureMode.voice =>
          _voicePath == null
              ? 'Hold the button to record'
              : 'Add a note if you want, then save',
        CaptureMode.object =>
          _objectTitle.isEmpty
              ? 'Give your object a name'
              : 'Add a story if you want, then save',
      };
    }

    switch (_captureMode) {
      case CaptureMode.voice:
        return _sealAsCapsule
            ? 'Tap SAVE CAPSULE to save'
            : 'Tap SAVE MEMORY to save';
      case CaptureMode.photo:
        return _sealAsCapsule
            ? 'Tap SAVE CAPSULE to save'
            : 'Tap SAVE MEMORY to save';
      case CaptureMode.object:
        return _sealAsCapsule
            ? 'Tap SAVE CAPSULE to save'
            : 'Tap SAVE MEMORY to save';
      default:
        if (_sealAsCapsule) {
          return 'Tap SAVE CAPSULE to save';
        }
        return 'Tap SAVE MEMORY to save';
    }
  }

  bool _canSave() {
    final requiresCapsuleDate = _sealAsCapsule && _capsuleUnlockDate == null;
    if (requiresCapsuleDate) return false;

    switch (_captureMode) {
      case CaptureMode.text:
        final text = _textController.text.trim();
        return text.isNotEmpty;
      case CaptureMode.photo:
        return _photoPath != null;
      case CaptureMode.voice:
        return _voicePath != null;
      case CaptureMode.object:
        return _objectTitle.trim().isNotEmpty;
    }
  }

  Future<bool> _saveEntry({bool fromDismiss = false}) {
    if (_saveFuture != null) {
      return _saveFuture!;
    }

    final saveFuture = _performSaveEntry(fromDismiss: fromDismiss);
    _saveFuture = saveFuture;
    return saveFuture.whenComplete(() => _saveFuture = null);
  }

  Future<bool> _performSaveEntry({bool fromDismiss = false}) async {
    // Bulletproof: if already explicitly saved, never save again
    if (_wasExplicitlySaved) return true;

    if (!_canSave()) {
      return false;
    }

    if (_isSaving) {
      return false;
    }
    _isSaving = true;
    _didPopDuringSave = false;

    try {
      final creator = ref.read(entryCreatorProvider.notifier);
      final capsuleUnlockDate = _sealAsCapsule ? _capsuleUnlockDate : null;

      switch (_captureMode) {
        case CaptureMode.text:
          final text = _textController.text.trim();
          switch (_selectedType) {
            case EntryType.line:
              await creator.createLineEntry(
                text,
                capsuleUnlockDate: capsuleUnlockDate,
              );
              break;
            case EntryType.fragment:
              await creator.createFragmentEntry(
                text.isEmpty ? null : text,
                capsuleUnlockDate: capsuleUnlockDate,
              );
              break;
            case EntryType.release:
              await creator.createReleaseEntry(
                text.isEmpty ? null : text,
                capsuleUnlockDate: capsuleUnlockDate,
              );
              break;
            default:
              break;
          }
          break;

        case CaptureMode.photo:
          if (_photoPath != null) {
            final text = _photoText.trim();
            await creator.createPhotoEntry(
              _photoPath!,
              text: text.isEmpty ? null : text,
              capsuleUnlockDate: capsuleUnlockDate,
            );
          }
          break;

        case CaptureMode.voice:
          if (_voicePath != null) {
            final text = _voiceText.trim();
            await creator.createVoiceEntry(
              _voicePath!,
              text: text.isEmpty ? null : text,
              capsuleUnlockDate: capsuleUnlockDate,
            );
          }
          break;

        case CaptureMode.object:
          final title = _objectTitle.trim();
          if (title.isNotEmpty) {
            final story = _objectStory.trim();
            await creator.createObjectEntry(
              title,
              mediaPath: _objectPhotoPath,
              text: story.isEmpty ? null : story,
              capsuleUnlockDate: capsuleUnlockDate,
            );
          }
          break;
      }

      if (_sealAsCapsule) {
        await HapticService.onCapsuleCreated();
      } else {
        HapticFeedback.lightImpact();
      }

      _wasExplicitlySaved = true;

      if (!fromDismiss && mounted) {
        _didPopDuringSave = true;
        Navigator.of(context).pop();
      }
      return true;
    } catch (e, st) {
      ref
          .read(errorReporterProvider)
          .report(e, stack: st, context: 'QuickCaptureSheet._saveEntry');
      if (!fromDismiss && mounted) {
        setState(() {
          _saveError = 'Could not save this memory. Please try again.';
        });
      }
      return false;
    } finally {
      _isSaving = false;
    }
  }

  bool _hasDraftContent() {
    return switch (_captureMode) {
      CaptureMode.text => _textController.text.trim().isNotEmpty,
      CaptureMode.photo => _photoPath != null || _photoText.trim().isNotEmpty,
      CaptureMode.voice => _voicePath != null || _voiceText.trim().isNotEmpty,
      CaptureMode.object =>
        _objectTitle.trim().isNotEmpty ||
            _objectStory.trim().isNotEmpty ||
            _objectPhotoPath != null,
    };
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
