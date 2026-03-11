# iOS Signed Release

## Prerequisites

- Xcode installed
- Apple Developer access
- Apple Distribution certificate
- provisioning profiles for `Runner` and `SeedlingWidgetExtension`
- App Store Connect app record for `com.seedling.seedling`

Detailed setup:
- [credentials-and-portal-setup.md](credentials-and-portal-setup.md)

## Capabilities

Confirm the signed build matches:
- App Group `group.com.seedling.seedling`
- iCloud container `iCloud.com.seedling.seedling`
- widget extension signing

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release
```

Expected output:
- `build/ios/ipa/*.ipa`

## Manual Validation

- archive/export succeeds without signing errors
- app launches on device
- widget extension signs and embeds correctly
- CloudKit availability state is handled cleanly

## Upload

Upload the signed `.ipa` to TestFlight/App Store Connect from Xcode Organizer or Transporter.
