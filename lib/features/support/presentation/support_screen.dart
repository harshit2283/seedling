import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../core/constants/support_links.dart';
import '../../../core/platform/adaptive_icons.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/widgets/feedback/seedling_toast.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// "Support Seedling" — a quiet page about how Seedling is made and paid for.
///
/// Seedling is free and open source. Nothing here unlocks anything. The page
/// is only ever reached on purpose (Settings → Support Seedling, or the
/// single one-time invitation); it never appears on its own.
///
/// Links come from [SupportLinks]. A `null` link hides its row, so no
/// placeholder account is ever shown. Links are copied to the clipboard
/// rather than opened, which keeps Seedling free of any browser-launching
/// dependency; swap [_openLink] for `url_launcher` if one is ever added.
class SupportScreen extends StatelessWidget {
  const SupportScreen({
    super.key,
    this.payWhatYouWantUrl = SupportLinks.payWhatYouWantUrl,
    this.githubSponsorsUrl = SupportLinks.githubSponsorsUrl,
    this.fundedSoFar = SupportLinks.fundedSoFar,
  });

  /// Overridable for tests; defaults to [SupportLinks].
  final String? payWhatYouWantUrl;
  final String? githubSponsorsUrl;
  final List<String> fundedSoFar;

  static const _title = 'Support Seedling';

  @override
  Widget build(BuildContext context) {
    final body = _SupportBody(
      payWhatYouWantUrl: payWhatYouWantUrl,
      githubSponsorsUrl: githubSponsorsUrl,
      fundedSoFar: fundedSoFar,
    );

    if (PlatformUtils.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.systemGroupedBackground.withValues(
            alpha: 0.7,
          ),
          border: null,
          middle: const Text(_title),
          leading: CupertinoNavigationBarBackButton(
            color: SeedlingColors.forestGreen,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        child: SafeArea(
          child: Material(type: MaterialType.transparency, child: body),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
        leading: IconButton(
          icon: Icon(AdaptiveIcons.back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: body,
    );
  }
}

class _SupportBody extends StatelessWidget {
  const _SupportBody({
    required this.payWhatYouWantUrl,
    required this.githubSponsorsUrl,
    required this.fundedSoFar,
  });

  final String? payWhatYouWantUrl;
  final String? githubSponsorsUrl;
  final List<String> fundedSoFar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = PlatformUtils.isIOS;
    final textTheme = Theme.of(context).textTheme;
    final secondary = isDark
        ? SeedlingColors.textSecondaryDark
        : SeedlingColors.textSecondary;
    final accent = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Opening
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(AdaptiveIcons.leaf, color: accent, size: 36),
              const SizedBox(height: 16),
              Text(
                'Seedling is free, and always will be.',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Every part of it is yours whether or not you ever pay. '
                'Nothing is locked, nothing expires, and nothing changes if '
                'you simply keep planting.',
                style: textTheme.bodyMedium?.copyWith(color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _Card(
          title: 'What Seedling promises',
          children: const [
            _Promise('No ads, ever.'),
            _Promise('No tracking and no analytics.'),
            _Promise('No account needed.'),
            _Promise('Nothing locked behind payment.'),
            _Promise(
              'Your memories are files you own. Export everything, any time.',
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Card(
          title: 'Why support matters',
          children: [
            _Paragraph(
              'Seedling is made by one person, in the open. Support buys '
              'time: fixing bugs, keeping up with new phones and OS updates, '
              'and making it a little lovelier each season. It keeps '
              'Seedling independent, answerable only to the people who use it.',
              color: secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Card(
          title: 'What it is never for',
          children: [
            _Paragraph(
              'Not ads, not growth tricks, not selling data, not making '
              'Seedling louder. If something would make you feel watched or '
              'hurried, money won\'t be spent on it.',
              color: secondary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Card(
          title: 'Ways to help',
          padded: false,
          children: [
            if (payWhatYouWantUrl != null)
              _LinkRow(
                icon: isIOS ? CupertinoIcons.heart : Icons.favorite_border,
                title: 'Pay what you want',
                subtitle: 'Once, any amount, no strings',
                url: payWhatYouWantUrl!,
              ),
            if (githubSponsorsUrl != null)
              _LinkRow(
                icon: isIOS ? CupertinoIcons.gift : Icons.volunteer_activism,
                title: 'GitHub Sponsors',
                subtitle: 'Support ongoing care',
                url: githubSponsorsUrl!,
              ),
            const _LinkRow(
              icon: Icons.star_border,
              title: 'Star or contribute on GitHub',
              subtitle: 'Read the code, fix a bug, share an idea',
              url: SupportLinks.repositoryUrl,
            ),
            const _LinkRow(
              icon: Icons.translate,
              title: 'Help translate',
              subtitle: 'Bring Seedling to your language',
              url: SupportLinks.translateUrl,
            ),
            _ActionRow(
              icon: isIOS ? CupertinoIcons.chat_bubble : Icons.chat_outlined,
              title: 'Tell a friend',
              subtitle: 'Only if you think they\'d like it',
              onTap: () => _tellAFriend(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Card(
          title: 'What support has funded',
          children: [
            if (fundedSoFar.isEmpty)
              _Paragraph(
                'Nothing to report yet. When support pays for something '
                '(a release, a translation, an accessibility fix) it will '
                'be listed here, plainly.',
                color: secondary,
              )
            else
              for (final item in fundedSoFar) _Promise(item),
          ],
        ),
        const SizedBox(height: 28),

        Text(
          'Thank you for being here. That is already enough.',
          style: textTheme.bodyMedium?.copyWith(
            color: secondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _tellAFriend(BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      await Share.share(
        'Seedling is a quiet, private place to keep small memories. '
        'Free and open source: ${SupportLinks.repositoryUrl}',
      );
    } catch (_) {
      if (context.mounted) await _openLink(context, SupportLinks.repositoryUrl);
    }
  }
}

/// Copies [url] and says so. Seedling has no browser-launching dependency.
Future<void> _openLink(BuildContext context, String url) async {
  HapticFeedback.selectionClick();
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  showSeedlingMessage(context, 'Link copied. Paste it in your browser.');
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
    this.padded = true,
  });

  final String title;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = PlatformUtils.isIOS ? 20.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? SeedlingColors.textSecondaryDark
                    : SeedlingColors.textSecondary,
              ),
            ),
          ),
        ),
        GlassContainer(
          borderRadius: radius,
          opacity: 0.75,
          border: Border.all(
            color: isDark
                ? SeedlingColors.dividerDark
                : SeedlingColors.softCream,
          ),
          child: Padding(
            padding: padded
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              AdaptiveIcons.leaf,
              size: 16,
              color: isDark
                  ? SeedlingColors.leafGreenDark
                  : SeedlingColors.leafGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: color, height: 1.45),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return _ActionRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _openLink(context, url),
      semanticsHint: 'Copies the link',
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.semanticsHint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? SeedlingColors.forestGreenDark
        : SeedlingColors.forestGreen;
    return Semantics(
      button: true,
      hint: semanticsHint,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? SeedlingColors.textMutedDark
                            : SeedlingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AdaptiveIcons.chevronRight,
                size: 18,
                color: isDark
                    ? SeedlingColors.textMutedDark
                    : SeedlingColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
