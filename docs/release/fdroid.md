# F-Droid readiness

_Status: **not ready.** Assessed October 2026 against the code on `main`._

F-Droid builds every app from source and only ships apps whose entire
dependency tree is free software, with no proprietary Google libraries and
no prebuilt closed binaries. Seedling's own code is MIT and has no
analytics, ads, or tracking, which is the hard part done. The blockers are
third-party dependencies.

ML Kit is no longer a dependency: theme detection and related memories are
pure Dart (`lib/core/services/ai/`), and the unused `MLTextAnalyzerPlugin`
(with its `com.google.mlkit` and coroutines Gradle dependencies) was removed.
The app no longer downloads a Google language model at startup.

ObjectBox is no longer a dependency either: the local database is SQLite
through `drift`, encrypted with SQLCipher (both open source). What remains
for storage is *how* SQLCipher gets into the APK (see the table).

## Dependency audit (Android)

| Dependency | Used for | F-Droid status | Notes |
| --- | --- | --- | --- |
| `google_sign_in` (pulls `play-services-auth`, `credentials-play-services-auth`) | Google Drive sync sign-in | **Blocker**: proprietary GMS | Only imported by `lib/core/services/sync/google_drive_sync_service.dart` |
| `googleapis`, `extension_google_sign_in_as_googleapis_auth` | Drive REST calls | Pure Dart and open source, but useless without sign-in | Remove alongside `google_sign_in` |
| `drift`, `sqlite3` (SQLCipher community edition, OpenSSL on Android) | The local, encrypted database | Open source (MIT; SQLite public domain; SQLCipher BSD-style; OpenSSL Apache-2.0). **Build-process blocker**: `package:sqlite3`'s build hook downloads *prebuilt* SQLCipher libraries from its GitHub releases (sha256-pinned, SLSA-attested), and F-Droid builds everything from source | Use the hook's `source: source` mode in the `foss` recipe to compile from the amalgamation (see step 3) |
| `audioplayers_android`, `receive_sharing_intent` | Playback, share intake | OK | Vendored under `third_party/flutter_packages/` |
| `local_auth`, `flutter_secure_storage`, `flutter_local_notifications`, `home_widget`, `image_picker`, `record`, `permission_handler`, `share_plus`, `file_picker`, `flutter_image_compress`, `package_info_plus`, `path_provider`, `shared_preferences` | Various | Expected OK (AndroidX / AOSP only) | Re-check transitive deps with the F-Droid scanner (`fdroid scanner`) once a build exists |
| Flutter SDK | Framework | OK | F-Droid builds Flutter apps using a pinned Flutter srclib |

Other items:

- **Application ID** is `com.twotwoeightthreelabs.seedling`. Keep it for the
  F-Droid build, or use a `.foss` suffix if both builds should coexist.
- **Release signing** currently fails the build without
  `SEEDLING_KEYSTORE_PATH`. F-Droid signs with its own key (or verifies a
  reproducible build), so the `foss` flavor must not require it.
- **Metadata:** F-Droid wants `fastlane/metadata/android/<locale>/`
  (title, short and full description, screenshots, changelogs). None exists yet.
- **Anti-features:** with the plan below, none should apply. Without it the
  app would be tagged `NonFreeDep` / `NonFreeNet` at best.

## Proposed `foss` flavor

Goal: one codebase, two Android builds. `play` keeps today's behaviour;
`foss` contains no Google proprietary code and makes no network connections
of its own.

1. **Gradle flavors.** In `android/app/build.gradle.kts` add
   `flavorDimensions += "distribution"` with `play` and `foss`.
2. **Drop Google Drive from the Dart build.** Flutter flavors don't remove
   pub dependencies, so:
   - Put a tiny `SyncBackend` factory in front of `GoogleDriveSyncService`
     and hide the Drive option when
     `const bool.fromEnvironment('SEEDLING_FOSS')` is true.
   - For the `foss` build, apply a `pubspec_overrides.yaml` (generated in
     CI / the F-Droid recipe) that points `google_sign_in` and
     `extension_google_sign_in_as_googleapis_auth` at local, API-compatible,
     no-native-code stubs under `third_party/foss_stubs/`.
   - Build with
     `flutter build apk --flavor foss --dart-define=SEEDLING_FOSS=true`.
   - Android then has no cloud sync in the `foss` build; local export and
     encrypted backup still work. A future WebDAV or Syncthing-friendly
     folder sync could fill the gap without proprietary code.
3. **Storage: build SQLCipher from source.** In the `foss` recipe, set the
   `sqlite3` hook to `source: source` (`hooks.user_defines.sqlite3` in
   `pubspec.yaml`, via the generated `pubspec_overrides.yaml` or a recipe
   patch) and point it at a vendored amalgamation:
   - SQLCipher's amalgamation needs a crypto provider built for Android
     (OpenSSL or BoringSSL from source, passed with `additional_includes` /
     `additional_libraries`), or
   - the SQLite3 Multiple Ciphers amalgamation, which carries its own
     ciphers (no OpenSSL) and reads SQLCipher-format files with
     `PRAGMA cipher = 'sqlcipher'`, so the database stays the same format.
   Either way `SeedlingDatabase` must still see a non-empty
   `PRAGMA cipher_version` (it refuses to open otherwise); with SQLite3MC
   that check needs adapting.
4. **CI.** Add a `foss` job to `.github/workflows/quality.yml` that builds
   the flavor and fails if `com.google.android.gms`, `com.google.mlkit`, or
   `com.google.firebase` show up in `./gradlew :app:dependencies --configuration fossReleaseRuntimeClasspath`.
5. **Metadata and recipe.** Add `fastlane/metadata/android/en-US/`, then
   submit an `fdroiddata` merge request with a recipe that runs the
   override step and the flavored build.

## Order of work

1. Gradle flavors, Drive stubs + `SEEDLING_FOSS` gating.
2. SQLCipher (or SQLite3MC) from source for the `foss` build.
3. CI guard, metadata, `fdroiddata` submission.
