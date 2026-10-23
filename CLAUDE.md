# Seedling - Claude Project Guide

## Project Overview

Seedling is a memory-keeping app that feels like breathing, not documenting. It uses the "Seeds → Trees → Forest" metaphor where memories grow into a visual tree over time.

**Core Philosophy:**
- No gamification (no streaks, badges, or scores); calm mode hides even counts
- Gentle reminders and nudges exist but are opt-in and off by default; nothing nags
- No social features (private to the user)
- Local-first; optional cloud sync, off by default and gated behind explicit opt-in
- Offline-first (must work without internet)
- No required fields (every field optional except timestamp)
- Two-second capture: open, type or attach, swipe down. Never ask what kind of memory it is
- Haptic feedback on interactions
- Soft, organic animations that honour Reduce Motion
- Open source (MIT) and free; nothing is ever locked behind payment (see "Open Source & Support")

## Quick Commands

```bash
# Run on iOS simulator
flutter run -d iphone

# Run on Android emulator
flutter run -d android

# Run tests (real-store tests need libobjectbox on LD_LIBRARY_PATH, else they skip)
flutter test

# Analyze code
flutter analyze

# No hard-coded light-only colors in lib/features (also enforced by a test)
bash scripts/check_palette.sh

# Regenerate ObjectBox models after changes
dart run build_runner build --delete-conflicting-outputs

# Regenerate tree goldens (Linux only, pinned Flutter 3.47.7)
flutter test --update-goldens test/features/tree_illustration_golden_test.dart
```

CI (`.github/workflows/quality.yml`) runs format, analyze, the palette check
and tests on Flutter 3.47.7. Native code and OS integration are checked by hand
with `docs/release/device-verification.md`.

## Architecture

### Directory Structure
```
lib/
├── main.dart                 # Opens DB, media, prefs, diagnostics log; hardens iOS dirs; runs app
├── app/
│   ├── app.dart              # Root MaterialApp/CupertinoApp shell, lifecycle, widget-URI allowlist
│   ├── app_lock_gate.dart    # AppLockGate: app stays mounted but Offstage + ExcludeFocus while locked
│   ├── router.dart           # GoRouter configuration (/entry/:id, /settings/*, /review/:year, ...)
│   └── theme/
│       ├── palette.dart      # SeedlingPalette ThemeExtension (light/dark) + context.palette
│       ├── radius.dart       # SeedlingRadius (20 iOS / 12 Android)
│       ├── colors.dart       # SeedlingColors raw constants (feed the palette; don't use in features)
│       ├── typography.dart   # SeedlingTypography (system font iOS; Georgia headlines Android)
│       ├── seedling_theme.dart / cupertino_theme.dart
├── features/
│   ├── tree/
│   │   ├── domain/           # resurfacing.dart ("From your tree" pick), tree_personality.dart
│   │   └── presentation/     # tree_screen, forest_screen, animated_tree_visualization,
│   │       ├── painting/     #   tree_blueprint (per-year seed), tree_illustration, tree_art_palette
│   │       └── widgets/      #   from_your_tree_card, backup_reminder_card, empty_state, ...
│   ├── capture/
│   │   ├── domain/           # capture_inference.dart (infers type), capture_intent.dart
│   │   └── presentation/     # quick_capture_sheet, shared_content_sheet,
│   │       └── widgets/      #   voice_capture_content, capsule_capture_content, release_ceremony
│   ├── memories/presentation/ # memories_screen, memory_card, entry_detail_screen,
│   │                          # memory_reader_screen, object_gallery_screen, widgets/
│   ├── prompts/              # Gentle prompts: data/, domain/prompt_selector, presentation/prompt_card
│   ├── onboarding/           # First-run flow + optional capture intention
│   ├── review/               # Year in Review (domain generator + screen)
│   ├── capsules/presentation/ # Memory Capsules list, card, unlock animation
│   ├── settings/presentation/ # settings_screen composes widgets/*_section.dart;
│   │                          # deleted_entries, rituals, theme_insights screens
│   └── support/              # Support Seedling page + one-time invitation
├── data/
│   ├── models/               # entry.dart, ritual.dart, tree.dart (ObjectBox), sync_id.dart
│   └── datasources/local/objectbox_database.dart  # CRUD, batch save, soft/hard delete, capsules
└── core/
    ├── constants/            # prefs_keys.dart (every prefs key), support_links.dart
    ├── platform/             # platform_utils.dart, adaptive_icons.dart
    ├── widgets/              # glass/glass_container.dart, feedback/seedling_toast.dart (showSeedlingMessage)
    └── services/
        ├── providers.dart    # Barrel: re-exports providers/*.dart
        ├── providers/        # database, sync, ai, media, capture, settings, resurfacing
        ├── error_reporter.dart  # Single error sink: debugPrint in debug, DiagnosticsLog always
        ├── diagnostics_log.dart # On-device, redacted, rotating JSONL log (Settings > About > Share)
        ├── ai/               # theme_detector_service + theme_lexicon, connection_finder_service,
        │                     #   ritual_detection_service, models/
        ├── sync/             # sync_engine, sync_crypto_service, sync_media_crypto, sync_metadata,
        │                     #   drive_sync_log (per-device log protocol), cloudkit/google_drive backends
        ├── export/           # export_service, markdown_export/format, journal_import (Day One,
        │                     #   Markdown), safe_zip (SafeZipReader), backup_codec, export_cleanup
        ├── backup/           # backup_restore_service (merge/replace + sync queue), backup_reminder_service
        ├── security/         # at_rest_encryption, app_lock, clock_guard, secure_storage, ios_data_protection
        ├── media/            # capture, compression, file storage, playback, draft_media_tracker
        ├── storage/          # storage_usage_service, media_orphan_sweeper
        ├── notifications/    # gentle_reminder_service (reminders + weekly resurfacing nudge)
        ├── transcription/    # speech_transcription_service (on-device only, iOS)
        ├── ritual/ share/ widget/   # rituals, share intake, home widget data (debounced)
        ├── haptic_service.dart
        └── entry_type_usage_service.dart
```

### Tech Stack
- **Database:** ObjectBox 5.1 (local, reactive)
- **State Management:** Riverpod 3.2
- **Routing:** GoRouter 17 (Flutter deep linking disabled; see Key Patterns)
- **Media:** image_picker, record, audioplayers, flutter_image_compress
- **Export/Import:** share_plus, archive (writing), `SafeZipReader` (all reading), file_picker
- **Preferences:** shared_preferences
- **On-device analysis:** pure Dart (weighted-lexicon themes, TF-IDF related memories). No ML frameworks, no model downloads
- **Share Extension:** receive_sharing_intent (vendored and patched in `third_party/`)
- **Home Widgets:** home_widget, WidgetKit (iOS), AppWidgetProvider (Android)
- **Security:** local_auth, flutter_secure_storage, cryptography (AES-GCM, PBKDF2, HKDF, HMAC)
- **Sync (opt-in):** CloudKit (iOS, native plugin), google_sign_in + googleapis (Drive appDataFolder)
- **Notifications:** flutter_local_notifications (opt-in, off by default)
- **Platforms:** iOS 15+, Android

### Native Plugins
| Platform | File | Purpose |
|----------|------|---------|
| iOS | `ios/Runner/CloudKitSyncPlugin.swift` | CloudKit as a file store: `SeedlingFile {name, data: CKAsset}` records in private zone `SeedlingSync` |
| iOS | `ios/Runner/SpeechTranscriptionPlugin.swift` | Voice memo transcription; `requiresOnDeviceRecognition = true` |
| iOS | `ios/Runner/MediaFileProtectionPlugin.swift` | File protection class + backup exclusion for DB and media |
| iOS | `ios/Runner/AppIntentsPlugin.swift` | Siri / Shortcuts App Intents |
| iOS | `ios/SeedlingWidget/SeedlingWidget.swift` | WidgetKit widget (`privacySensitive` memory text, calm mode) |
| Android | `.../SpeechTranscriptionPlugin.kt` | Reports unavailable: no on-device file transcription on Android |
| Android | `.../SeedlingWidgetProvider.kt` | Home screen widget (calm mode hides counts) |
| Android | `.../MainActivity.kt` | Screen-protection (`FLAG_SECURE`) channel |

None of the Swift/Kotlin is compiled in CI. Anything touching it goes through
`docs/release/device-verification.md`.

### Key Patterns

**Database Access:**
```dart
// Always access via provider
final db = ref.read(databaseProvider);
await db.saveEntry(entry);
```

**Creating Entries:**
```dart
// Use factory constructors
Entry.line(text: "A thought")
Entry.fragment(text: null)  // Empty is valid
Entry.release(text: "Letting go")
Entry.photo(mediaPath: "/path/to/photo.jpg", text: "Optional note")
Entry.voice(mediaPath: "/path/to/voice.m4a", text: "Optional note")
Entry.object(title: "Grandma's ring", mediaPath: "/path/to/object.jpg", text: "Story")
Entry.capsule(text: "Message", unlockDate: futureDate)
```

**Capture (two-second capture):** the quick capture sheet opens on a focused
text field and never asks for a type. `inferCaptureType()`
(`lib/features/capture/domain/capture_inference.dart`) decides on save:
explicit Let go / Ritual → voice recording → title (Object) → photo → text
(Fragment when under 15 characters, else Line). Fragment is merged into Line in
the UI (one "Line" filter covers both) but kept in the data. A memory holds
**one** photo or **one** voice memo: adding the other kind asks first, and the
old file goes only once its replacement exists. Swipe down saves (same path as
back/barrier, guarded by `_wasExplicitlySaved`). Post-save side effects are
best-effort; once the entry is written, the memory counts as saved.

**Colors and shape:** feature widgets read `context.palette`
(`SeedlingPalette`, light and dark) and `SeedlingRadius`, never
`SeedlingColors.text*`, `forestGreen`, `Colors.white/black`.
`scripts/check_palette.sh` and `test/app/palette_usage_test.dart` fail on
violations (allowlist: tree painter, photo viewer, or `// palette: allow`). Use
`palette.inkFor(accent)` for AA text on accent fills.

**Soft delete and letting go:**
```dart
await db.softDeleteEntry(entryId);   // Recently Deleted, 30 days
await db.restoreEntry(entryId);
final deleted = db.getDeletedEntries();
await db.purgeExpiredEntries();      // also queues remote deletes for sync
```
The only hard delete without the trash is the release ceremony's explicit
"Let it go completely" (after a Let go entry is saved; "Keep it in the tree" is
the default and what closing does). It deletes the entry and media, says so
plainly, and is skipped for sealed release capsules.

**Deep links:** Flutter deep linking is off (`FlutterDeepLinkingEnabled` /
`flutter_deeplinking_enabled` = false). Only `seedling://capture`, `home` and
`today` are handled, by the allowlist in `lib/app/app.dart`; capture waits for
app unlock.

**Tree Growth Thresholds:**
- Seed: 0-10 entries
- Sprout: 11-30 entries
- Sapling: 31-100 entries
- Young Tree: 101-250 entries
- Mature Tree: 251-500 entries
- Ancient Tree: 501+ entries

## Data Models

### Entry Types
| Type | Purpose | Required Fields |
|------|---------|-----------------|
| LINE | Text that stayed with you | None (text optional) |
| PHOTO | Image capture | mediaPath |
| VOICE | Voice memo | mediaPath |
| OBJECT | Physical object | title |
| FRAGMENT | Incomplete thought (short line; inferred, not chosen) | None |
| RITUAL | Recurring moment | title |
| RELEASE | Letting go | None |

### Entry fields worth knowing
| Field | Purpose |
|-------|---------|
| isDeleted, deletedAt | Soft delete (30-day trash) |
| capsuleUnlockDate | Capsule; `isCapsule`, `isLocked`, `isUnlocked` getters |
| detectedTheme | Persisted at save, edit and import |
| manualLinkIds | User-made links (syncUUIDs; they sync). Related memories are computed, never stored |
| syncUUID, modifiedAt | Sync identity and last-write-wins clock |
| mediaAssetId, mediaKey | Remote encrypted media blob and its per-file key (key encrypted at rest) |

Written fields (text, title, context, mood, tags, transcription, theme, links,
mediaKey) and ritual names are encrypted at rest with a Keychain/Keystore key.

### Media Storage Structure
```
<app_documents>/media/
├── photos/       # Photo entries (UUID.jpg)
├── voices/       # Voice memos (UUID.m4a)
└── objects/      # Object photos (UUID.jpg)
```
`DraftMediaTracker` deletes media a draft drops; `MediaOrphanSweeper` removes
unreferenced files older than 24h once per launch (never an open draft's).
On iOS, `objectbox/` and `media/` are excluded from device backups.

### Tree States
Trees represent a calendar year. Growth is based on **count**, not frequency (no pressure for daily entries).

## Design Guidelines

### Platform-Adaptive UI (IMPORTANT)

The app should feel native on each platform. **iOS should use glass/translucent effects** following Apple's modern design language.

#### iOS-Specific (Cupertino)
- Use `CupertinoNavigationBar` with translucent backgrounds
- Glass effect sheets with `BackdropFilter` and `ImageFilter.blur(sigmaX: 30, sigmaY: 30)`
- SF Pro font (system default on iOS)
- Large title navigation style
- Translucent tab bars and toolbars
- iOS-style sliding page transitions
- Avoid a `BackdropFilter` per list item (it re-blurs every scroll frame); use near-opaque palette fills

```dart
// Glass effect container for iOS
ClipRRect(
  borderRadius: SeedlingRadius.card,
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: Container(
      decoration: BoxDecoration(
        color: context.palette.glassTint,
        borderRadius: SeedlingRadius.card,
        border: Border.all(color: context.palette.border),
      ),
      child: content,
    ),
  ),
)
```

#### Platform Detection
```dart
import 'dart:io' show Platform;

// Use throughout UI
if (Platform.isIOS) {
  // Cupertino widgets, glass effects
} else {
  // Material widgets
}
```

#### iOS Components to Use
| Instead of (Material) | Use (iOS) |
|----------------------|-----------|
| `AppBar` | `CupertinoNavigationBar` with `backgroundColor: Colors.transparent` |
| `BottomSheet` | `CupertinoPopupSurface` with blur |
| `AlertDialog` | `CupertinoAlertDialog` |
| `TextField` | `CupertinoTextField` |
| `Switch` | `CupertinoSwitch` |
| `Slider` | `CupertinoSlider` |
| `CircularProgressIndicator` | `CupertinoActivityIndicator` |
| `ListTile` | `CupertinoListTile` |
| `SearchBar` | `CupertinoSearchTextField` |

### Colors (SeedlingPalette)
- Read semantic colors from `context.palette`: `textPrimary/Secondary/Muted`, `primary`, `primaryFill`/`onPrimaryFill`, `surface`, `card`, `border`, `divider`, `glassTint`, `error`, `success`, `warning`, `accentLine/Photo/Voice/Object/Fragment/Ritual/Release`, theme colors
- `SeedlingColors` holds the raw brand constants (forestGreen #2D5A3D, creamPaper #FAF8F5, accents) that the palette is built from
- Dark mode is a warm "forest twilight", not a cold grey; contrast is tested (WCAG AA) in `test/app/palette_contrast_test.dart`

### Typography and shape
- **iOS:** system font (SF Pro). **Android:** Georgia headlines, system sans body
- Minimum 12pt for secondary text; touch targets ≥ 44pt with a semantics label
- **Border radius:** `SeedlingRadius` (20 iOS / 12 Android; `small` for chips)

### Interactions
- Light haptic on save: `HapticFeedback.lightImpact()`
- Selection click on buttons: `HapticFeedback.selectionClick()`
- Medium haptic on recording start: `HapticFeedback.mediumImpact()`
- Heavy haptic on max duration reached: `HapticFeedback.heavyImpact()`
- Soft transitions: `Curves.easeOutCubic`, 200-800ms duration
- Under Reduce Motion (`MediaQuery.disableAnimations`): no sway, slides or bursts; crossfade or jump instead
- Feedback via `showSeedlingMessage` with a light tap; no modal "Done/OK" for successes

## Development Guidelines

### Do
- Keep capture friction-free (swipe down to save; infer the type)
- Use factory constructors for Entry creation
- Watch streams for reactive UI updates
- Test tree state boundaries (10, 30, 100, 250, 500)
- **Use platform-adaptive widgets** (Cupertino on iOS, Material on Android)
- **Apply glass/blur effects on iOS** for sheets and overlays
- Use `context.palette` and `SeedlingRadius` for every color and radius in features
- Compress images before saving (1920x1920 max, 85% quality)
- Use UUID for media filenames to prevent collisions
- Use soft delete for user data (30-day recovery window)
- Show user messages with `showSeedlingMessage(context, ...)` (`lib/core/widgets/feedback/seedling_toast.dart`), not `ScaffoldMessenger.of(context)`: the iOS shell is a `CupertinoApp` with no `Scaffold`
- Keep the lock screen in `AppLockGate` (`lib/app/app_lock_gate.dart`)
- Put restore/import logic in `BackupRestoreService`, and queue what it creates/deletes for sync (`queueForSync`)
- Read every archive through `SafeZipReader` (`lib/core/services/export/safe_zip.dart`): counts and declared sizes are checked before inflating, zip-slip/symlinks refused
- Report errors through `ErrorReporter.report` (never `debugPrint` in release paths); it feeds the redacted `DiagnosticsLog`
- Test database behaviour against a real store with `ObjectBoxDatabase.openForTesting(directory:, encryptionService:)`; it needs `libobjectbox` on the loader path and skips itself otherwise
- Keep voice transcription strictly on-device: iOS requires on-device recognition and Android reports unavailable. Never fall back to a server recognizer
- Keep notification copy generic (no memory text, titles or dates) and Android `NotificationVisibility.private`
- Add every SharedPreferences key to `PrefsKeys`, and create secure storage only via `createSeedlingSecureStorage()` (device-only keychain accessibility)
- Update `PRIVACY.md` whenever what leaves the device changes

### Don't
- Add gamification features
- Require explanations for memories, or ask people to pick a memory type up front
- Call setState() during deactivate/dispose
- Use mechanical animations (prefer organic curves)
- **Use Material widgets on iOS** (looks out of place)
- Hard-code colors (`check_palette.sh` will fail)
- Auto-play voice memos (manual playback only)
- Record for more than 2 minutes (auto-stop with haptic)
- Hard delete user data without recovery option (the explicit "Let it go completely" is the one exception)
- Auto-save in deactivate without bulletproof double-save guards (use `_wasExplicitlySaved` flag checked at top of save function)
- Cache provider values in local state when reactivity is needed (use `ref.watch()` in build instead)
- Score or judge memories (no sentiment, no mood arcs)
- Nag. No launch popups, counters, streak-style guilt, or repeated asks. Reminders are opt-in and off by default
- Lock any feature behind payment, or show supporters anything non-supporters can't see
- Add analytics, crash reporting, ads, or any network call that isn't an explicit, opt-in user action

### Open Source & Support
Seedling is MIT-licensed and free. People may choose to pay; nothing is ever locked.
- The Support Seedling page lives at `/settings/support` (`lib/features/support/`), reached only from Settings > About or the one-time invitation
- **Never nag; one invitation, ever.** The only invitation is `SupportInvitationCard` at the end of Year in Review. It claims its single showing in SharedPreferences (`PrefsKeys.supportInvitationShown`) the first time it mounts and never appears again, whether dismissed, followed, or ignored. Don't add a second placement or a "remind me later"
- All links live in `lib/core/constants/support_links.dart`. Donation/sponsor links stay `null` until a real account exists, and `null` rows are hidden. Never invent an account
- In-app tip jar is a documented hook only (`SupportLinks.inAppTipProductId`); a tip must never change the app

#### Dispose discipline
Every long-lived object created by a `State` must be released in `dispose()`. Failing to do so leaks memory and can fire callbacks on disposed widgets.
- `AnimationController`: always call `.dispose()`; never reuse across rebuilds.
- `StreamController`: always `.close()`; closing it also drops broadcast listeners.
- `StreamSubscription`: store the subscription and `.cancel()` in `dispose()`.
- `TextEditingController`: always `.dispose()`; if it was passed in by a parent, do NOT dispose, just drop the reference.
- `FocusNode`: always `.dispose()` unless the node was provided by an ancestor.
- `ScrollController` / `PageController` / `TabController`: always `.dispose()`.
- `Timer` (and `Timer.periodic`): always `.cancel()`; check before reassigning.

## Phase Roadmap

- **Phase 1 (Complete):** Foundation - LINE, FRAGMENT, RELEASE capture, tree visualization
- **Phase 1.5 (Complete):** Platform-Adaptive UI - iOS glass effects, Cupertino components
- **Phase 2 (Complete):** Media - Photo, voice, object capture with full UI
- **Phase 3 (Complete):** Polish - Edit/delete, filters, export, gentle prompts
- **Phase 4 (Complete):** On-device themes and related memories, rituals (suggest-only)
- **Phase 4.5 (Complete):** Widgets & Capsules - Home widgets, share extension, dark mode, haptics, memory capsules
- **Phase 5 (Implemented):** Illustrated tree, two-second capture, resurfacing, release ceremony, calm mode, encrypted backup and import, E2E-encrypted sync incl. media, Year in Review, diagnostics
- **Open source:** MIT, free, nothing locked; Support Seedling page

## Feature notes

### Memories list and detail (Phase 3)
- Search (`CupertinoSearchTextField` on iOS), type and theme filter chips (44pt), newest/oldest sort
- Detail view with edit mode, related and linked memories, transcription (iOS), soft delete
- Memory reader (`/memories/reader`): swipe through memories on both platforms; chrome stays up for screen readers
- Recently Deleted at Settings > Recently Deleted (restore or delete permanently)

### Gentle prompts
- Time-of-day and seasonal prompts on the tree screen, 8-hour cooldown, auto-dismissed once anything is saved today
- Optional **capture intention** from onboarding ("When do small moments find you?", `PrefsKeys.captureIntention`): shown softly as the capture hint, editable under Settings > Prompts > Your moment
- Fully optional: Settings > Prompts

### Resurfacing ("From your tree")
- `resurfacedMemoryProvider` picks one memory a day (`lib/features/tree/domain/resurfacing.dart`): this day in an earlier year first, else one at least 30 days old, deterministic per date, rolling over at midnight
- Never sealed capsules, trashed or released memories. Card hides until tomorrow on dismiss
- Opt-in (off by default) weekly local notification, Sunday 10:00, generic lock-screen-safe copy ("A memory is waiting for you"), scheduled only when something can be resurfaced. Toggle: Settings > Prompts

### Calm mode
- `calmModeProvider` (Settings > Your tree, off by default): the tree still grows, but entry counts, stage labels and progress bars disappear from the tree screen, forest, Year in Review, theme chips and home widgets (incl. semantics labels)

### Themes and related memories (on-device, pure Dart)
- Full write-up and evaluation: `docs/engineering/themes.md`
- **Themes:** 11 categories (family, friends, work, nature, gratitude, reflection, travel, creativity, health, food, moments). `ThemeDetectorService.analyze()` is a weighted-lexicon classifier (`theme_lexicon.dart`: inflections, spelling/accent folding, typos, phrases, blockers, negation, field weights) returning primary, secondary and confidence; `moments` only when nothing reaches enough evidence
- Detected at save (and on edit/import) and persisted; never re-themed in the background
- `test/services/ai/theme_eval_test.dart` enforces held-out macro-F1 and accuracy ≥ 0.78 on `test/fixtures/theme_eval.json`. Never tune on the held-out split
- **Related memories:** `ConnectionFinderService` ranks by TF-IDF cosine over the user's own collection plus shared people/places; theme and time only re-rank. Evaluated by `connection_eval_test.dart`
- Theme Insights (Settings) shows distribution; no sentiment anywhere

### Rituals
- Detection only suggests (`ritualCandidatesProvider`); a ritual exists only after the person confirms it. No ritual reminders are scheduled

### Capsules (Phase 4.5)
- `Entry.capsule(...)`; sealed content stays out of the memories feed, the link picker and Year in Review until it opens. `ClockGuardService` resists clock rollback
- Queries: `getLockedCapsules()`, `getUnlockedCapsules()`, `getCapsulesToUnlockToday()`

### Home widgets and share extension (Phase 4.5)
- Widget data via `home_widget`, debounced (1s) and deduped. Memory text is off by default, forced off while app lock is on, and `privacySensitive` on iOS
- iOS App Groups need manual setup: add `group.com.seedling.seedling` to both Runner and SeedlingWidgetExtension (Signing & Capabilities)
- Share intake: text/URL → Line, image → Photo, only after the person confirms. Android copies shared files to `cache/shared_intake/` under random names (never the sender's display name)

### Cloud sync (opt-in, format v1)
- Off by default; requires `cloudSyncEnabledProvider` and a passphrase. Nothing touches the network before the opt-in (`networkAllowed`)
- **Keys:** PBKDF2 with a random per-user salt kept in a **keyring** file in the user's sync space, plus an encrypted **key check** so a wrong passphrase is rejected before anything is stored. Concurrent keyrings settle on the smallest salt. Only a derived key is stored (Keychain, device-only)
- **Records:** `syncEncryptionVersion: 1`; written fields AES-256-GCM with AAD binding `syncUUID|field|version`; each record carries an HMAC-SHA256 (`syncMac`) over all keys, metadata included. Anything else (other versions, no MAC) is set aside, never imported
- **Transport:** each device appends to its own change log (`seedling_sync_log_<deviceId>_<epoch>_b<seq>|c<from>-<to>.json`); keyring files `seedling_sync_keyring_<deviceId>.json` with sequence numbers; deletes are log tombstones. Same protocol on Drive (appDataFolder) and CloudKit (custom zone `SeedlingSync`, `SeedlingFile` records)
- **Media:** end-to-end encrypted per file (random key, 64 KiB authenticated chunks), uploaded as `seedling_media_<uuid>.bin`, downloaded in the background after the record arrives; files > 50 MB are skipped
- **Quarantine:** records that fail decryption/authentication are set aside in a local file (`SyncQuarantine`), retried on every pull, and shown in Settings as a calm notice (`syncQuarantineCountProvider`, `SyncQuarantineNotice`), not as an error
- Last-write-wins on `modifiedAt` (local wins ties); push/pull serialized; every backend call has a timeout; `init()` never throws
- A full upload is queued on first enable, when the key changes, and before an idle device's log is retired
- No migrations: the app never shipped, so every format (sync, keyring, backup, Markdown, ObjectBox model) is version 1 and older layouts are not read

### Export, backup and import
- Export as JSON, ZIP, Markdown (open format, Obsidian-friendly, sealed capsules filed separately) or encrypted backup (format 1: exactly PBKDF2-SHA256 600k, HMAC signature required); temp files are deleted after sharing. Sizes are checked against what restore accepts before reading media
- Import: encrypted backup, Seedling ZIP, Day One JSON export, Seedling Markdown. Parsed off the UI isolate, previewed (new / already here / media), merged without overwriting or duplicating
- Device backups don't include memories; Settings > Privacy says so ("Keeping a copy")

### Diagnostics
- `DiagnosticsLog`: last 200 errors, redacted before storage (quoted values, paths, URIs, emails removed; 5 frames). Shared only when the person taps Settings > About > Share diagnostics

### Tree (Phase 5)
- `AnimatedTreeVisualization(state:, progress:, season:, seed:, memoryLights:, showGrowthDetails:, celebrateGrowth:, onTap:)`
- Hand-illustrated procedural tree grown from a per-year `TreeBlueprint` (growth only adds limbs and leaves), seasonal art palette with a moonlit dark variant, memory lights for the last two weeks
- The settled tree is rasterised once; idle sway is a single transform. Reduce Motion: no sway or bursts
- Season by month: spring Mar-May, summer Jun-Aug, autumn Sep-Nov, winter Dec-Feb

### Year in Review
- Annual summary, theme garden, seasons and timeline; under 10 memories it shows "still taking shape" instead of a gate. Shareable cards are optional

## Testing

Run `flutter test` (about 820 tests). Each test file runs on its own; there is no aggregator file, so don't add one (it double-counts).

Coverage includes entry models, tree boundaries and blueprint determinism,
capture inference and the capture sheet, theme and connection evaluation
sets, sync engine/crypto/media crypto/Drive and CloudKit log protocol, backup
restore, export/import (Markdown, Day One, SafeZipReader), real ObjectBox
store behaviour (`test/data/`), palette usage and contrast, calm mode, Reduce
Motion, accessibility targets, and tree goldens (no text, 0.5% tolerance,
Linux only).

Device-only checks (native code, keychain, backups, widgets, notifications,
screen readers, large exports, real Day One files) are listed in
`docs/release/device-verification.md`.

## Troubleshooting

**ObjectBox generation fails:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**CocoaPods issues on iOS:**
```bash
cd ios && pod install
```

**iOS deployment target error:**
Ensure `ios/Podfile` has: `platform :ios, '15.0'`

**Permission denied on camera/mic:**
Check that Info.plist has NSCameraUsageDescription, NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription

**Real-store tests skipped:**
Put `libobjectbox.so` on `LD_LIBRARY_PATH` (CI downloads objectbox-c 5.1.0).

**Golden test fails locally on macOS/Windows:**
Goldens are compared on Linux only. Regenerate on Linux with Flutter 3.47.7.

**iOS Widget not showing data:**
Ensure App Groups capability is enabled for both Runner and SeedlingWidgetExtension targets with `group.com.seedling.seedling`.

**Android Widget not updating:**
Widget updates (debounced) after entry changes and when the app is backgrounded. Force update by removing and re-adding the widget. Check that `SeedlingWidgetProvider` is registered in AndroidManifest.xml.

**CloudKit works in Debug but not TestFlight:**
Deploy the Development schema (`SeedlingFile {name: String, data: Asset}`) to Production. See `docs/release/device-verification.md` §1.

## Rule: always use qmd before reading files

Before reading files or exploring directories, always use qmd to search for information in local projects.

Available tools:

- `qmd search “query”` — fast keyword search (BM25)

- `qmd query “query”` — hybrid search with reranking (best quality)

- `qmd vsearch “query”` — semantic vector search

- `qmd get <file>` — retrieve a specific document

Use qmd search for quick lookups and qmd query for complex questions.

Use Read/Glob only if qmd doesn’t return enough results.