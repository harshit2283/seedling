# Public Configuration Guide

Seedling is designed to run locally without private credentials.

## Works Out Of The Box

- local database
- media capture and playback
- local encryption features
- exports and imports
- widgets

## Optional Private Configuration

### iOS Signing And CloudKit

Required only for signed device builds, widgets, and CloudKit sync:
- Apple Developer team access
- app identifiers and provisioning profiles
- App Group `group.com.seedling.seedling`
- iCloud container `iCloud.com.seedling.seedling`

### Google Drive Backup

Required only if you want Google Drive backup/sign-in:
- Google Cloud project
- Drive API enabled
- OAuth consent screen
- iOS OAuth client for `com.seedling.seedling`
- Android OAuth clients for debug and release SHA fingerprints

### Android Release Signing

Required only for signed release artifacts:
- release keystore
- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

## iOS Local Secret Files

Use ignored local config files for any private xcconfig values. Do not commit:
- `ios/Flutter/LocalSecrets.xcconfig`
- `ios/Flutter/*.private.xcconfig`

## Google Sign-In Note

If you add Google Sign-In on iOS, append its URL scheme to the existing
`CFBundleURLTypes` entries instead of replacing the checked-in `seedling://`
scheme.
