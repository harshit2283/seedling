/// Every outbound link the "Support Seedling" screen can show, in one place.
///
/// Seedling is free and open source (MIT). Paying is always optional and
/// never unlocks anything. These links exist so people who *want* to help
/// can find a way to.
///
/// Rules for editing this file:
/// - Never invent an account. A `null` link hides its row on the screen.
/// - Only fill a donation/sponsor link once the account really exists and
///   is owned by the maintainer.
/// - Keep [fundedSoFar] honest: list only things support actually paid for.
class SupportLinks {
  SupportLinks._();

  /// Source code, issues, and contributions.
  static const String repositoryUrl = 'https://github.com/harshit2283/seedling';

  /// Where to report a bug or suggest an idea.
  static const String issuesUrl = '$repositoryUrl/issues';

  /// The privacy policy, kept next to the code (PRIVACY.md).
  static const String privacyPolicyUrl = '$repositoryUrl/blob/main/PRIVACY.md';

  /// How to contribute code, docs, or translations.
  static const String contributingUrl =
      '$repositoryUrl/blob/main/CONTRIBUTING.md';

  /// Translation help. Until a dedicated translation platform exists this
  /// points at the contributing guide.
  static const String translateUrl = contributingUrl;

  /// Pay-what-you-want page (e.g. Ko-fi, Liberapay, Open Collective).
  /// `null` until a real account exists — the row stays hidden.
  static const String? payWhatYouWantUrl = null;

  /// GitHub Sponsors profile. `null` until enabled — the row stays hidden.
  static const String? githubSponsorsUrl = null;

  /// In-app "tip jar" hook.
  ///
  /// Out of scope for now: it needs App Store Connect / Play Console
  /// products. To add it later, create a consumable product in both stores,
  /// put its identifier here, and render a tip row in
  /// `SupportScreen` when this is non-null. A tip must never unlock a
  /// feature, badge, or any visible difference in the app.
  static const String? inAppTipProductId = null;

  /// Short plain-language notes of what support has paid for, newest first.
  /// Empty until there is something true to say.
  static const List<String> fundedSoFar = <String>[];
}
