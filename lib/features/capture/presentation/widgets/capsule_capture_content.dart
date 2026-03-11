import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/platform/platform_utils.dart';

/// Content widget for capturing time capsule entries
class CapsuleCaptureContent extends StatefulWidget {
  final String initialText;
  final DateTime? initialUnlockDate;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<DateTime?> onUnlockDateChanged;

  const CapsuleCaptureContent({
    super.key,
    required this.initialText,
    required this.initialUnlockDate,
    required this.onTextChanged,
    required this.onUnlockDateChanged,
  });

  @override
  State<CapsuleCaptureContent> createState() => _CapsuleCaptureContentState();
}

class _CapsuleCaptureContentState extends State<CapsuleCaptureContent> {
  late TextEditingController _textController;
  DateTime? _selectedDate;

  // Quick date presets
  static const List<_DatePreset> _presets = [
    _DatePreset('1 Week', Duration(days: 7)),
    _DatePreset('1 Month', Duration(days: 30)),
    _DatePreset('3 Months', Duration(days: 90)),
    _DatePreset('6 Months', Duration(days: 180)),
    _DatePreset('1 Year', Duration(days: 365)),
    _DatePreset('5 Years', Duration(days: 365 * 5)),
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _selectedDate = widget.initialUnlockDate;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? SeedlingColors.textPrimaryDark
        : SeedlingColors.textPrimary;
    final textSecondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final textMuted = isDark
        ? SeedlingColors.textMutedDark
        : SeedlingColors.textMuted;
    final accentColor = isDark
        ? SeedlingColors.themeGratitudeDark
        : SeedlingColors.themeGratitude;
    final cardColor = isDark
        ? SeedlingColors.cardDark
        : SeedlingColors.softCream;
    final borderColor = isDark
        ? SeedlingColors.borderDark
        : SeedlingColors.softCream;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                PlatformUtils.isIOS
                    ? CupertinoIcons.archivebox
                    : Icons.inventory_2_outlined,
                color: accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time Capsule',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Write a message to your future self',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Text input
        Container(
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: _buildTextField(isDark, textPrimary, textMuted),
        ),

        const SizedBox(height: 16),

        // Unlock date section
        Text(
          'UNLOCK DATE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Date presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final preset in _presets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildPresetChip(preset, isDark, accentColor),
                ),
              _buildCustomDateButton(isDark, accentColor),
            ],
          ),
        ),

        // Selected date display
        if (_selectedDate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  PlatformUtils.isIOS ? CupertinoIcons.calendar : Icons.event,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unlocks on ${_formatDate(_selectedDate!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDate = null);
                    widget.onUnlockDateChanged(null);
                  },
                  child: Icon(
                    PlatformUtils.isIOS
                        ? CupertinoIcons.xmark_circle_fill
                        : Icons.cancel,
                    color: textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(bool isDark, Color textPrimary, Color textMuted) {
    if (PlatformUtils.isIOS) {
      return CupertinoTextField(
        controller: _textController,
        maxLines: 4,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        placeholder: 'Dear future me...',
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText,
          fontSize: 16,
        ),
        style: TextStyle(fontSize: 16, color: textPrimary),
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: const EdgeInsets.all(12),
        onChanged: widget.onTextChanged,
      );
    }

    return TextField(
      controller: _textController,
      maxLines: 4,
      minLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: textPrimary),
      decoration: InputDecoration(
        hintText: 'Dear future me...',
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: textMuted),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(12),
      ),
      onChanged: widget.onTextChanged,
    );
  }

  Widget _buildPresetChip(_DatePreset preset, bool isDark, Color accentColor) {
    final targetDate = DateTime.now().add(preset.duration);
    final isSelected =
        _selectedDate != null &&
        _selectedDate!.year == targetDate.year &&
        _selectedDate!.month == targetDate.month &&
        _selectedDate!.day == targetDate.day;

    final backgroundColor = isDark
        ? SeedlingColors.surfaceDark
        : SeedlingColors.warmWhite;
    final borderColor = isDark
        ? SeedlingColors.borderDark
        : SeedlingColors.softCream;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDate = targetDate);
        widget.onUnlockDateChanged(targetDate);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? accentColor
                : (isDark
                      ? SeedlingColors.textSecondaryDark
                      : SeedlingColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateButton(bool isDark, Color accentColor) {
    final isCustomSelected =
        _selectedDate != null &&
        !_presets.any((p) {
          final target = DateTime.now().add(p.duration);
          return _selectedDate!.year == target.year &&
              _selectedDate!.month == target.month &&
              _selectedDate!.day == target.day;
        });

    final backgroundColor = isDark
        ? SeedlingColors.surfaceDark
        : SeedlingColors.warmWhite;
    final borderColor = isDark
        ? SeedlingColors.borderDark
        : SeedlingColors.softCream;

    return GestureDetector(
      onTap: () => _showDatePicker(context, isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isCustomSelected
              ? accentColor.withValues(alpha: 0.15)
              : backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCustomSelected ? accentColor : borderColor,
            width: isCustomSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PlatformUtils.isIOS
                  ? CupertinoIcons.calendar
                  : Icons.calendar_today,
              size: 16,
              color: isCustomSelected
                  ? accentColor
                  : (isDark
                        ? SeedlingColors.textSecondaryDark
                        : SeedlingColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCustomSelected
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: isCustomSelected
                    ? accentColor
                    : (isDark
                          ? SeedlingColors.textSecondaryDark
                          : SeedlingColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, bool isDark) {
    HapticFeedback.selectionClick();

    final now = DateTime.now();
    final minDate = now.add(const Duration(days: 1));
    final maxDate = now.add(const Duration(days: 365 * 10)); // 10 years max

    if (PlatformUtils.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => Container(
          height: 300,
          color: isDark
              ? SeedlingColors.surfaceDark
              : CupertinoColors.systemBackground,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Done'),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onUnlockDateChanged(_selectedDate);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? minDate,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  onDateTimeChanged: (date) {
                    setState(() => _selectedDate = date);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDatePicker(
        context: context,
        initialDate: _selectedDate ?? minDate,
        firstDate: minDate,
        lastDate: maxDate,
      ).then((date) {
        if (date != null) {
          setState(() => _selectedDate = date);
          widget.onUnlockDateChanged(date);
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DatePreset {
  final String label;
  final Duration duration;

  const _DatePreset(this.label, this.duration);
}
