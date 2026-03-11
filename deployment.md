# Seedling Deployment Guide

Manual-first release flow for signed mobile artifacts.

## Signed Outputs

- iOS signed `.ipa` for TestFlight / App Store Connect
- Android signed `.aab` for Play Console
- Android signed `.apk` for direct install / internal testing

## iOS

Prerequisites:
- macOS with Xcode installed (required for `flutter build ipa`)
- Apple Developer access
- Apple Distribution certificate
- provisioning profiles for `Runner` and `SeedlingWidgetExtension`
- App Store Connect app record for `com.seedling.seedling`
- App Group `group.com.seedling.seedling`
- iCloud container `iCloud.com.seedling.seedling`

See [docs/release/ios-release.md](docs/release/ios-release.md) for full environment validation and signing details before building the IPA.

Build:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release
```

Output:
- `build/ios/ipa/*.ipa`

## Android

Required env vars:
- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

Signed AAB:

```bash
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Output:
- `build/app/outputs/bundle/release/app-release.aab`

Signed APK:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Output:
- `build/app/outputs/flutter-apk/app-release.apk`

## Optional Publishing Automation

Not required for manual releases.

If you later automate publishing, you will need:
- App Store Connect API `.p8`, issuer ID, key ID
- Google Play service account JSON

## Optional Google Drive Backup Setup

Google Drive backup is not required for shipping signed artifacts, but if you use it you will need:
- Google Cloud project
- Drive API enabled
- OAuth consent screen
- iOS OAuth client for `com.seedling.seedling`
- Android OAuth clients for debug/release signing fingerprints

See:
- [docs/release/ios-release.md](docs/release/ios-release.md)
- [docs/release/android-release.md](docs/release/android-release.md)
- [docs/release/release-checklist.md](docs/release/release-checklist.md)
- [docs/release/credentials-and-portal-setup.md](docs/release/credentials-and-portal-setup.md)
