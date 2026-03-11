# Credentials And Portal Setup

This guide covers the external setup required to produce a proper signed release of Seedling on iOS and Android.

It is split into:
- Apple Developer / App Store Connect
- Google Cloud for Google Drive backup
- Android release signing / Play Console
- optional publishing automation

This repo's release identifiers are:
- iOS app bundle ID: `com.seedling.seedling`
- iOS widget bundle ID: `com.seedling.seedling.SeedlingWidget`
- iOS App Group: `group.com.seedling.seedling`
- iOS CloudKit container: `iCloud.com.seedling.seedling`
- Android package: `com.twotwoeightthreelabs.seedling`

## 1. Apple Developer And App Store Connect

Use this section if you want a signed `.ipa` for TestFlight or App Store release.

### 1.1 Required Accounts

You need:
- an Apple ID
- Apple Developer Program membership
- enough permissions to manage certificates, identifiers, and profiles

### 1.2 Add Your Apple Account In Xcode

1. Open Xcode.
2. Go to `Xcode > Settings > Accounts`.
3. Click `+`.
4. Sign in with the Apple ID tied to your developer membership.

### 1.3 Create The App Store Connect App Record

1. Open App Store Connect.
2. Go to `Apps`.
3. Click `+` then `New App`.
4. Fill:
   - platform: `iOS`
   - name: `Seedling`
   - primary language
   - bundle ID: `com.seedling.seedling`
   - SKU: any unique internal string, for example `seedling-ios-001`

### 1.4 Register The App IDs

In Apple Developer `Certificates, Identifiers & Profiles`:

Create or confirm these App IDs:
- main app: `com.seedling.seedling`
- widget extension: `com.seedling.seedling.SeedlingWidget`

### 1.5 Enable Required Capabilities

For the main app, enable:
- App Groups
- iCloud
- CloudKit

For the widget extension, enable:
- App Groups

Use these exact values:
- App Group: `group.com.seedling.seedling`
- CloudKit container: `iCloud.com.seedling.seedling`

These must match:
- [`ios/Runner/Runner.entitlements`](../../ios/Runner/Runner.entitlements)
- [`ios/SeedlingWidget/SeedlingWidget.entitlements`](../../ios/SeedlingWidget/SeedlingWidget.entitlements)

### 1.6 Create The Apple Distribution Certificate

Recommended path for a manual release:

1. In Xcode go to `Xcode > Settings > Accounts`.
2. Select your team.
3. Click `Manage Certificates`.
4. Click `+`.
5. Choose `Apple Distribution`.

This creates and installs the certificate in your login keychain.

Alternative CSR/manual path:

1. Open `Keychain Access`.
2. Go to `Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority`.
3. Enter your email and common name.
4. Choose `Saved to disk`.
5. Save the CSR file.
6. In Apple Developer portal, create a new `Apple Distribution` certificate using that CSR.
7. Download the certificate and double-click it to install it into Keychain.

Back up access to the certificate/private key if this will be used from multiple Macs.

### 1.7 Configure Signing In Xcode

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` target.
3. Open `Signing & Capabilities`.
4. Select your Team.
5. Enable `Automatically manage signing`.
6. Confirm bundle ID is `com.seedling.seedling`.
7. Confirm App Groups and CloudKit are present.
8. Repeat for `SeedlingWidgetExtension`:
   - Team selected
   - automatic signing enabled
   - bundle ID `com.seedling.seedling.SeedlingWidget`
   - App Group `group.com.seedling.seedling`

### 1.8 Build The Signed IPA

From the repo root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release
```

Expected output:
- `build/ios/ipa/*.ipa`

If signing fails, check:
- the Apple account in Xcode
- your selected team
- certificate installed in Keychain
- app IDs and capabilities
- provisioning profiles for both Runner and widget extension

### 1.9 Upload To TestFlight / App Store

Upload using one of:
- Xcode Organizer
- Apple Transporter app

You will also need to complete:
- screenshots
- age rating
- app privacy answers
- review notes

## 2. Google Cloud Setup For Google Drive Backup

Use this section only if you want Google Drive backup/sign-in.

Important:
- you do not need a generic Google Drive API key for this app
- you need OAuth client configuration
- the repo intentionally does not commit those credentials

### 2.1 Create Or Select A Google Cloud Project

1. Open Google Cloud Console.
2. Create a new project or choose an existing one.
3. Keep track of the project name and project ID.

### 2.2 Enable The Google Drive API

1. In the Cloud Console, open `APIs & Services > Library`.
2. Search for `Google Drive API`.
3. Click `Enable`.

### 2.3 Configure The OAuth Consent Screen

1. Open `APIs & Services > OAuth consent screen`.
2. Choose `External` unless this is only for a private Google Workspace organization.
3. Fill:
   - app name
   - support email
   - developer contact email
4. Add scopes required by sign-in/Drive access.
5. If the app is still in testing mode, add your own Google account as a test user.

### 2.4 Create The iOS OAuth Client

1. Open `APIs & Services > Credentials`.
2. Click `Create credentials > OAuth client ID`.
3. Choose `iOS`.
4. Bundle ID: `com.seedling.seedling`
5. Save the client.

Record:
- the iOS client ID
- the reversed client ID / URL scheme if required by your chosen Google Sign-In path

If you add the iOS URL scheme, append it to the existing `CFBundleURLTypes` in:
- [`ios/Runner/Info.plist`](../../ios/Runner/Info.plist)

Do not remove the existing `seedling` URL scheme.

### 2.5 Create Android OAuth Clients

You usually need:
- one Android OAuth client for debug signing
- one Android OAuth client for release signing

Each Android OAuth client requires:
- package name: `com.twotwoeightthreelabs.seedling`
- SHA-1 certificate fingerprint

#### Debug SHA-1

You can read your debug SHA-1 with:

```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android \
  -keypass android
```

#### Release SHA-1

After generating your release keystore, read its SHA-1 with:

```bash
keytool -list -v \
  -alias <your_release_alias> \
  -keystore /path/to/seedling-release.jks
```

Then:
1. Open `APIs & Services > Credentials`.
2. Click `Create credentials > OAuth client ID`.
3. Choose `Android`.
4. Package name: `com.twotwoeightthreelabs.seedling`
5. Paste the SHA-1 fingerprint.
6. Save.

Repeat for both debug and release fingerprints.

### 2.6 What To Store Outside Git

Keep these outside git:
- Google Cloud project details
- iOS OAuth client ID
- Android OAuth client IDs
- any iOS plist or local config values needed by the chosen Google Sign-In flow

## 3. Android Release Signing

Use this section if you want a signed `.aab` and signed `.apk`.

### 3.1 Generate The Release Keystore

Run:

```bash
keytool -genkeypair -v \
  -keystore seedling-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias seedling-release
```

You will be prompted for:
- keystore password
- key password
- owner information

Store these safely. Losing them can block app updates.

### 3.2 Required Environment Variables

This repo reads release signing from:
- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

Example:

```bash
export SEEDLING_KEYSTORE_PATH=/absolute/path/to/seedling-release.jks
export SEEDLING_KEYSTORE_PASSWORD='your-keystore-password'
export SEEDLING_KEY_ALIAS='seedling-release'
export SEEDLING_KEY_PASSWORD='your-key-password'
```

These values are required by:
- [`android/app/build.gradle.kts`](../../android/app/build.gradle.kts)

### 3.3 Build Signed Android Artifacts

Signed AAB:

```bash
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Expected output:
- `build/app/outputs/bundle/release/app-release.aab`

Signed APK:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Expected output:
- `build/app/outputs/flutter-apk/app-release.apk`

### 3.4 Play Console Setup

1. Create or access a Google Play Developer account.
2. Open Play Console.
3. Create the app using package name `com.twotwoeightthreelabs.seedling`.
4. Enroll in Play App Signing if you want Google to manage the production signing key.

Recommended:
- use Play App Signing
- keep your local keystore as the upload key

## 4. Optional Publishing Automation

These are not required for manual releases.

### iOS Automation

If you later automate App Store Connect uploads, you will need:
- App Store Connect API key `.p8`
- issuer ID
- key ID

### Android Automation

If you later automate Play uploads, you will need:
- Google Play service account JSON

## 5. Final Release Credential Checklist

### Required For Signed iOS Release

- Apple Developer Program membership
- Apple Distribution certificate
- provisioning for `Runner`
- provisioning for `SeedlingWidgetExtension`
- App Store Connect app record

### Required For Signed Android Release

- release keystore file
- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

### Required For Optional Google Drive Backup

- Google Cloud project
- Google Drive API enabled
- OAuth consent screen
- iOS OAuth client
- Android OAuth client for debug SHA-1
- Android OAuth client for release SHA-1

## 6. Recommended Order

If you are doing this for the first time, use this order:

1. Apple Developer setup and signed `.ipa`
2. Android release keystore and signed `.aab` / `.apk`
3. Google Drive OAuth setup
4. Optional store upload automation later
