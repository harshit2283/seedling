# Contributing

Seedling is currently in alpha.

This repository is public for transparency and reference, but external
contributions are not being accepted at this time.

## Setup

1. Install Flutter stable and platform toolchains.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test` before opening a PR.

## Optional Private Integrations

The public repo is runnable without Apple or Google cloud credentials.

These features require private configuration that is intentionally not committed:
- CloudKit-capable signed iOS builds
- Google Drive backup/sign-in
- Android release signing
- App Store / Play publishing

See [docs/open-source/configuration.md](docs/open-source/configuration.md) and [docs/open-source/secrets.md](docs/open-source/secrets.md).

## Pull Requests

Pull requests from external contributors are currently not being accepted.

Keep PRs focused. If you change privacy, sync, export, storage, or signing behavior:
- add or update tests
- update user-facing copy if behavior changed
- update release or setup docs if credentials/config expectations changed

Use the PR template and complete the quality gates.
