# Android Signed Release

## Required Environment Variables

- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

Detailed setup:
- [credentials-and-portal-setup.md](credentials-and-portal-setup.md)

These are enforced by [`android/app/build.gradle.kts`](../../android/app/build.gradle.kts).

## Signed AAB

```bash
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Expected output:
- `build/app/outputs/bundle/release/app-release.aab`

## Signed APK

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Expected output:
- `build/app/outputs/flutter-apk/app-release.apk`

Default policy:
- generate a universal signed APK unless split-per-ABI is explicitly needed

## Manual Validation

- app installs from signed APK
- release build launches cleanly
- Google Drive sign-in is tested against the release signing certificate fingerprint if that feature is enabled
