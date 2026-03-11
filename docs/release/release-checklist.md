# Release Checklist

## Repo

- `flutter analyze`
- `flutter test`
- no tracked secrets or signing assets
- README and public docs are current
- privacy copy matches current behavior

## iOS

- signing works for Runner and widget extension
- App Group and CloudKit capabilities match entitlements
- signed `.ipa` produced
- TestFlight/App Store metadata is ready

## Android

- release keystore env vars are set
- signed `.aab` produced
- signed `.apk` produced
- release sign-in configuration matches release SHA fingerprints

## Privacy

- widget previews remain off by default
- exports require device auth when App Lock is enabled
- encrypted backup leaves no plaintext intermediate archive
