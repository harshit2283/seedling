# Seedling

**Memory-keeping that feels like breathing, not documenting.**

Seedling is a small, private place to keep the moments that stay with you: a
line someone said, a photo, a voice memo, an object with a story, a half
thought. Each memory is a seed. Over a year they grow into a tree, and over
the years, a forest.

There are no streaks, badges, feeds, or followers. No field is required. You
don't have to explain anything. You just plant it and move on with your day.

Seedling is **free and open source** (MIT). Nothing is locked, and nothing
ever will be. If it means something to you, you can
[help keep it growing](#supporting-seedling), but you never have to.

## Screenshots

_Screenshots coming soon. Contributions of clean, sample-data screenshots
are welcome._

<!--
| Tree | Capture | Memories | Year in Review |
| ---- | ------- | -------- | -------------- |
| ![](docs/screenshots/tree.png) | ![](docs/screenshots/capture.png) | ![](docs/screenshots/memories.png) | ![](docs/screenshots/review.png) |
-->

## Features

- **Two-second capture:** the sheet opens ready to type. Attach a photo, hold
  to record a voice memo, or add a title, and Seedling works out whether it's
  a line, photo, voice memo, or object. Swipe down to save.
- **Let go, rituals, and capsules:** a quiet ceremony for things you're
  letting go (keep it in the tree, or let it go completely), rituals you
  confirm from your own patterns, and capsules that stay sealed until a date
  you choose.
- **A tree that grows by count, not frequency:** a hand-illustrated tree,
  unique to each year, from seed to ancient, with seasonal colours. Past
  years become a forest. **Calm mode** hides every count and stage label.
- **From your tree:** one past memory a day on the home screen, and an
  optional weekly nudge (off by default).
- **Gentle connections, all on-device:** themes, related memories, and a
  Year in Review. No sentiment scores, ever.
- **Search, filters, and a reading view** for wandering back through it all.
- **Your data, in open formats:** export as JSON, ZIP, Markdown (opens in
  Obsidian), or an encrypted backup; import from a Seedling export or Day One.
- **Home screen widgets, a share extension, and Siri / Shortcuts actions (iOS).**
- **Native and accessible on both platforms:** Cupertino with glass on iOS,
  Material on Android, warm light and dark themes, Reduce Motion support, and
  labelled 44pt controls for screen readers.
- **Optional, opt-in extras:** gentle reminders (off by default), app lock,
  and end-to-end encrypted cloud sync to your own account.

## Privacy model

Seedling is local-first. The full policy is in [PRIVACY.md](PRIVACY.md).

**On your device, always**
- All memories and media. Written fields are encrypted at rest with a key
  in the Keychain / Keystore; iOS media files use system file protection.
- All analysis: themes and related memories, in Seedling's own code, with no
  model downloads.
- Voice transcription (iOS only, on-device recognition required; Android
  doesn't transcribe rather than risk sending audio to a server).

**Only when you opt in**
- Cloud sync to *your* iCloud (CloudKit private database) or *your* Google
  Drive (hidden app-data folder). Off by default. Memory text, photos, and
  voice memos are encrypted end-to-end with a passphrase you choose before
  upload.
- Exports, encrypted backups, and sharing, which always go through the
  system share sheet to wherever you pick.
- Gentle reminders, the weekly "From your tree" nudge, app lock, and memory
  text in widgets.
- Sharing the on-device, redacted diagnostics log (Settings > About).

**Never**
- Accounts, analytics, ads, crash reporting, or developer-run servers.
- Your memories in device backups (iCloud/computer backups and Android app
  backup exclude them; export or sync to keep a copy).

**Threat model, briefly.** Seedling aims to protect your memories from the
developer (who receives nothing), from cloud providers (synced memories and
media are passphrase-encrypted and authenticated), and from casual access to
an unlocked phone (optional app lock). It does not protect against a
compromised or jailbroken device. Known gaps, listed openly in
[PRIVACY.md](PRIVACY.md#known-limitations): some sync metadata (dates, type)
is readable by the storage provider, and media files over 50 MB don't sync.

## Build and run

Requirements: Flutter stable (CI pins 3.47.7; Dart 3.10+), Xcode for iOS (iOS 15+), and the
Android SDK for Android.

```bash
flutter pub get
flutter analyze
flutter test          # or: make check
flutter run -d iphone # or: flutter run -d android
```

After changing an ObjectBox model in `lib/data/models/`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

A few tests run against a real ObjectBox store and are skipped unless the
native `libobjectbox` library is on the loader path (for example via
`LD_LIBRARY_PATH` on Linux).

You don't need Apple or Google credentials to build and run locally. CloudKit
sync, signed widgets, Google Drive, and store publishing need private
configuration; see [docs/open-source/configuration.md](docs/open-source/configuration.md)
and [docs/open-source/secrets.md](docs/open-source/secrets.md). Release steps
are in [docs/release/](docs/release/), including an honest
[F-Droid readiness assessment](docs/release/fdroid.md).

## Architecture

```
lib/
├── main.dart            # Opens DB, media, prefs, reminders; runs the app
├── app/                 # App shell, GoRouter routes, AppLockGate, theme
├── data/
│   ├── models/          # ObjectBox entities: Entry, Tree, Ritual
│   └── datasources/local/objectbox_database.dart  # CRUD, soft delete, capsules
├── core/
│   ├── constants/       # PrefsKeys, SupportLinks
│   ├── platform/        # Platform detection, adaptive icons
│   ├── widgets/         # Glass containers, showSeedlingMessage toasts
│   └── services/
│       ├── providers/   # Riverpod providers, split by domain
│       ├── ai/          # Lexicon theme detection, related memories, rituals (pure Dart)
│       ├── sync/        # Sync engine, crypto, per-device change logs, CloudKit + Drive
│       ├── security/    # At-rest encryption, app lock, clock guard
│       ├── backup/      # Backup reminders, BackupRestoreService
│       ├── export/      # JSON / ZIP / Markdown / encrypted export; Day One + Markdown import
│       ├── media/       # Capture, compression, storage, playback
│       ├── transcription/ notifications/ ritual/ share/ widget/ storage/
└── features/            # Screens: tree, capture, memories, capsules, prompts,
                         # review, onboarding, settings, support
```

- **State:** Riverpod 3. **Routing:** GoRouter. **Storage:** ObjectBox.
- **Native code:** `ios/Runner/` has Swift plugins for CloudKit sync, on-device
  speech, media file protection and backup exclusion, and App Intents;
  `android/app/src/main/kotlin/` has the widget provider and a transcription
  stub. None of it is compiled in CI; see
  [docs/release/device-verification.md](docs/release/device-verification.md).
- More detail for contributors (and AI assistants) lives in
  [CLAUDE.md](CLAUDE.md) and [docs/engineering/](docs/engineering/).

## Contributing

Contributions are welcome: bug fixes, accessibility, translations,
documentation, and thoughtful ideas. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) first. Security issues go through
[SECURITY.md](SECURITY.md), not public issues.

Ideas that add gamification, social features, tracking, or anything that
pressures people to use the app more will be declined, kindly.

## Supporting Seedling

Seedling is made by one person and will always be free. Support keeps it
independent and maintained; it never unlocks anything, and it will never pay
for ads or growth tricks. The app has a quiet **Settings → Support Seedling**
page and will invite you at most once, ever.

Ways to help: star the repo, contribute, translate, or tell a friend who might
like it. Donation links will appear here and in the app only once they exist.

## Credits and license

- Inspired in part by [Capturing your life while living](https://notesbyallie.substack.com/p/capturing-your-life-while-living).
- Planning documents in `docs/plans/` and some other docs began as
  LLM-assisted drafts and were adapted for this repository.

The code is [MIT-licensed](LICENSE). The `Seedling` name and `2283 Labs`
branding are not granted for reuse by this notice alone. If you fork or
redistribute this project, please use your own name and branding unless you
have separate written permission.
