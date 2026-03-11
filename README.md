# Seedling

Private-first memory keeping built with Flutter.

Seedling is local-first by default. Optional cloud sync, exports, widgets, and sharing are available, but they require explicit user action or private platform configuration.

## Requirements

1. Flutter stable
2. Xcode for iOS builds
3. Android SDK for Android builds

## Local Setup

```bash
flutter pub get
flutter analyze
flutter test
```

## Run

```bash
flutter run -d iphone
flutter run -d android
```

Public contributors do not need Apple or Google credentials to run the app locally.

## Optional Private Integrations

- CloudKit sync and widgets on signed iOS builds
- Google Drive backup/sign-in
- signed Android release builds
- App Store / Play publishing

See:
- [docs/open-source/configuration.md](docs/open-source/configuration.md)
- [docs/open-source/secrets.md](docs/open-source/secrets.md)
- [docs/release/ios-release.md](docs/release/ios-release.md)
- [docs/release/android-release.md](docs/release/android-release.md)
- [docs/release/credentials-and-portal-setup.md](docs/release/credentials-and-portal-setup.md)

## Privacy Notes

- Local storage is the default.
- Cloud sync is optional.
- Export and backup flows are explicit user actions.
- Widget memory previews are off by default.
- Speech transcription prefers on-device recognition where supported by platform and language.
- No analytics or ad tracking are included.

## Release Artifacts

- signed iOS `.ipa`
- signed Android `.aab`
- signed Android `.apk`

Release steps:
- [docs/release/release-checklist.md](docs/release/release-checklist.md)

## Project Docs

- `CLAUDE.md`
- `docs/plans/`
- `docs/engineering/coding-standards.md`
- `docs/engineering/testing-standards.md`
- `docs/engineering/manual-verification-matrix.md`

## Inspiration And Planning Notes

- A source of inspiration for this project was [Capturing your life while living](https://notesbyallie.substack.com/p/capturing-your-life-while-living).
- The planning documents in `docs/plans/` were created with LLM assistance.
- Some subsequent related documentation in `docs/` also began as LLM-assisted drafts and were then adapted for this repository.

## Open Source

- [LICENSE](LICENSE)
- [SECURITY.md](SECURITY.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

## Name And Branding

The code in this repository is MIT-licensed.

The `Seedling` name and `2283 Labs` branding are not granted for reuse by this
README notice alone. If you fork or redistribute this project, use your own
name and branding unless you have separate written permission.
