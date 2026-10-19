import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/palette.dart';
import '../../../../app/theme/radius.dart';
import '../../../../core/platform/adaptive_icons.dart';
import '../../../../core/platform/platform_utils.dart';

/// Picks the Cupertino glyph on iOS and the Material one elsewhere.
IconData adaptiveIcon(IconData cupertino, IconData material) =>
    PlatformUtils.isIOS ? cupertino : material;

/// The small tinted square that leads every settings row.
class SettingsIconBox extends StatelessWidget {
  const SettingsIconBox({
    super.key,
    required this.icon,
    this.color,
    this.isDanger = false,
    this.isWarm = false,
  });

  final IconData icon;
  final Color? color;
  final bool isDanger;

  /// A warm (gold) tint, used for the support row.
  final bool isWarm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ios = PlatformUtils.isIOS;
    final fg = isDanger
        ? palette.error
        : isWarm
        ? palette.accentGold
        : (color ?? palette.primary);
    final bg = isDanger
        ? palette.error.withValues(alpha: 0.15)
        : isWarm
        ? palette.accentGold.withValues(alpha: palette.isDark ? 0.2 : 0.16)
        : palette.primaryContainer.withValues(
            alpha: palette.isDark ? 0.7 : 0.55,
          );
    final size = ios ? 30.0 : 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ios ? 8 : 10),
      ),
      child: Icon(icon, color: fg, size: ios ? 17 : 19),
    );
  }
}

/// A titled group of settings rows: an inset grouped list on iOS, a rounded
/// card on Android.
///
/// The Android card is a [Material], not a coloured [Container], so row
/// ripples paint on the card itself instead of underneath it.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    required this.children,
    this.footer,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (PlatformUtils.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: title == null
            ? null
            : Semantics(header: true, child: Text(title!)),
        footer: footer == null ? null : Text(footer!),
        children: children,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: palette.card,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: SeedlingRadius.card,
                side: BorderSide(color: palette.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Divider(height: 1, indent: 64, color: palette.divider),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Text(
                footer!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One settings row. Tappable when [onTap] is set (with a chevron), and can
/// carry a short [value] on the right or any custom [trailing] widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.isDanger = false,
    this.isWarm = false,
    this.isLoading = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDanger;
  final bool isWarm;
  final bool isLoading;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final leading = SettingsIconBox(
      icon: icon,
      color: iconColor,
      isDanger: isDanger,
      isWarm: isWarm,
    );
    final tap = isLoading ? null : onTap;

    if (PlatformUtils.isIOS) {
      Widget? trail = trailing;
      if (isLoading) {
        trail = const CupertinoActivityIndicator();
      } else if (trail == null && onTap != null && showChevron) {
        trail = const CupertinoListTileChevron();
      }
      return CupertinoListTile(
        leading: leading,
        title: Text(
          title,
          style: isDanger ? TextStyle(color: palette.error) : null,
        ),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 3),
        additionalInfo: value == null ? null : Text(value!),
        trailing: trail,
        onTap: tap,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    Widget? trail = trailing;
    if (isLoading) {
      trail = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (trail == null && onTap != null && showChevron) {
      trail = Icon(AdaptiveIcons.chevronRight, color: palette.textMuted);
    }

    return InkWell(
      onTap: tap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDanger ? palette.error : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              if (trail != null) ...[const SizedBox(width: 8), trail],
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with an on/off switch. The whole row toggles.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.switchKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SettingsRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        showChevron: false,
        trailing: SettingsSwitch(
          key: switchKey,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// An adaptive switch whose "off" state stays legible in dark mode: a
/// visible outline and thumb instead of the default near-invisible track.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (PlatformUtils.isIOS) {
      return CupertinoSwitch(
        value: value,
        activeTrackColor: palette.primaryFill,
        inactiveTrackColor: palette.isDark ? palette.border : null,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: palette.primaryFill,
      activeThumbColor: palette.onPrimaryFill,
      inactiveTrackColor: palette.surfaceMuted,
      inactiveThumbColor: palette.isDark
          ? palette.textSecondary
          : palette.textMuted,
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : (palette.isDark ? palette.textMuted : palette.border),
      ),
    );
  }
}

/// Scaffold for a settings sub-screen (sync, export & import).
class SettingsSubScreen extends StatelessWidget {
  const SettingsSubScreen({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemGroupedBackground.withValues(
            alpha: 0.9,
          ),
          border: null,
          middle: Text(title),
          previousPageTitle: 'Settings',
        ),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              children: [...children, const SizedBox(height: 40)],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [...children, const SizedBox(height: 40)],
      ),
    );
  }
}

/// A short, quiet paragraph above or between settings groups.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.textSecondary,
      height: 1.45,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: palette.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
