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

## Dependency audit (Android)

| Dependency | Used for | F-Droid status | Notes |
| --- | --- | --- | --- |
| `google_sign_in` (pulls `play-services-auth`, `credentials-play-services-auth`) | Google Drive sync sign-in | **Blocker**: proprietary GMS | Only imported by `lib/core/services/sync/google_drive_sync_service.dart` |
| `googleapis`, `extension_google_sign_in_as_googleapis_auth` | Drive REST calls | Pure Dart and open source, but useless without sign-in | Remove alongside `google_sign_in` |
| `objectbox` / `objectbox_flutter_libs` | The local database | **Likely blocker**: the Dart bindings are open source, but the native core library ships as a prebuilt binary that, to our knowledge, is not open source | Confirm current licensing with ObjectBox and F-Droid before planning around it |
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
3. **Storage.** Resolve ObjectBox first; it decides whether F-Droid is
   possible at all:
   - If the native core is acceptable to F-Droid (or becomes open source),
     nothing changes.
   - If not, the honest options are a storage abstraction with a
     SQLite-based implementation (for example `drift` + SQLCipher) for
     `foss`, which is a substantial migration, or publishing the `foss` APK
     through **IzzyOnDroid** or GitHub Releases instead. Check IzzyOnDroid's
     current inclusion policy first.
4. **CI.** Add a `foss` job to `.github/workflows/quality.yml` that builds
   the flavor and fails if `com.google.android.gms`, `com.google.mlkit`, or
   `com.google.firebase` show up in `./gradlew :app:dependencies --configuration fossReleaseRuntimeClasspath`.
5. **Metadata and recipe.** Add `fastlane/metadata/android/en-US/`, then
   submit an `fdroiddata` merge request with a recipe that runs the
   override step and the flavored build.

## Order of work

1. Ask about ObjectBox licensing (blocks everything else).
2. Gradle flavors, Drive stubs + `SEEDLING_FOSS` gating.
3. CI guard, metadata, `fdroiddata` submission.
