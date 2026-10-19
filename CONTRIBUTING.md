# Contributing

Thank you for wanting to help Seedling grow. It's open source (MIT) and free,
and contributions are welcome: bug fixes, accessibility improvements,
translations, documentation, tests, and well-reasoned ideas.

Seedling is maintained by one person, so reviews may take a little while.
For anything larger than a small fix, please open an issue first so we can
agree on the shape before you spend time on it.

## What fits

Seedling should feel like breathing, not documenting. Changes that keep it
calm, private, and friction-free fit well. These won't be accepted:

- gamification (streaks, badges, scores) or pressure to use the app more
- social features, feeds, or public profiles
- analytics, tracking, ads, or any data sent to the developer
- anything that locks a feature behind payment
- nags: repeated prompts, launch popups, or guilt-based copy

## Setup

1. Install Flutter stable and platform toolchains.
2. Run `flutter pub get`.
3. Run `dart format .`, `flutter analyze`, and `flutter test` before opening a PR
   (`make check` runs analyze and test).

## Optional Private Integrations

The public repo is runnable without Apple or Google cloud credentials.

These features require private configuration that is intentionally not committed:
- CloudKit-capable signed iOS builds
- Google Drive backup/sign-in
- Android release signing
- App Store / Play publishing

See [docs/open-source/configuration.md](docs/open-source/configuration.md) and [docs/open-source/secrets.md](docs/open-source/secrets.md).

## Translations

Seedling doesn't have a translation pipeline yet. If you'd like to translate
it, open an issue naming the language. That will help decide how
localization gets set up.

## Pull Requests

Keep PRs focused. If you change privacy, sync, export, storage, or signing behavior:
- add or update tests
- update user-facing copy if behavior changed
- update [PRIVACY.md](PRIVACY.md) if what leaves the device changed
- update release or setup docs if credentials/config expectations changed

Use the PR template and complete the quality gates. By contributing, you
agree that your contribution is licensed under the MIT License.
