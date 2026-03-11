# Secrets Inventory

## Runtime / Local Feature Secrets

### CloudKit

- Stored outside git in Apple Developer / Xcode signing configuration
- Needed for signed iOS builds with CloudKit and widgets
- No runtime API key is embedded in app code

### Google Drive Backup

- Stored outside git in local platform config / Google Cloud Console
- Needed only for optional Google Drive backup/sign-in
- Uses OAuth client configuration, not a static Drive API key in app code

## Release Signing Secrets

### iOS

- Apple Distribution certificate
- provisioning profiles for Runner and widget extension

### Android

- release keystore
- `SEEDLING_KEYSTORE_PATH`
- `SEEDLING_KEYSTORE_PASSWORD`
- `SEEDLING_KEY_ALIAS`
- `SEEDLING_KEY_PASSWORD`

## Optional Automation Secrets

- App Store Connect API `.p8`, issuer ID, key ID
- Google Play service account JSON

These are not needed for local development or manual releases.

## Never Commit

- keystores
- provisioning profiles
- `.p8`, `.p12`, `.cer`
- `.env` files
- `android/key.properties`
- Google service/account credential files
- private xcconfig files
