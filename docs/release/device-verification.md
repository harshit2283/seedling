# Device verification checklist

Manual QA for behaviour that CI cannot check: native Swift/Kotlin code that is
never compiled on the Linux runner, OS integration (keychain, backups, lock
screen, widgets, notifications, deep links, share sheet), assistive
technology, and real-world data sizes. Everything here was written against
the code but **not** run on a device.

Run it before every release that touches the area, and at least once before
the first store submission. Record the build number, device, OS version and
pass/fail per item in the release notes or the release-checklist issue.

**Devices:** one iPhone on the oldest supported iOS (15) and one on the
current iOS; one Android phone on a recent Android (13+) with a secure lock
screen (PIN/pattern). Two devices signed into the **same** iCloud account for
CloudKit, and two devices signed into the same Google account for Drive.

**Build:** a Release (or TestFlight / internal testing) build, not Debug.
Several items depend on release-only behaviour (diagnostics never printing,
production CloudKit environment).

---

## 1. CloudKit sync (Swift rewrite) and production schema

`ios/Runner/CloudKitSyncPlugin.swift` now treats CloudKit as a small file
store. It uses exactly these record types and fields (from the Swift source):

| Record type | Zone | Fields | Used by |
| --- | --- | --- | --- |
| `SeedlingFile` | custom zone `SeedlingSync` (private DB) | `name`: String, `data`: Asset | `fsList`, `fsRead`, `fsWrite`, `fsDelete` (change logs, keyring, media blobs) |

File names (`name`, also used as the record name) are
`seedling_sync_log_<deviceId>_<epoch>_b<seq>.json` /
`…_c<from>-<to>.json`, `seedling_sync_keyring_<deviceId>.json` and
`seedling_media_<uuid>.bin`. There is no other record type: the app never
shipped, so no older layout is read.

### 1.1 Production schema is deployed

1. CloudKit Console → container `iCloud.com.seedling.seedling` →
   **Development** → Schema → Record Types.
2. Confirm `SeedlingFile` exists with `name` (String) and `data` (Asset). If it
   is missing, run a Debug build against Development and enable sync once so
   CloudKit creates it.
3. No index is required for `SeedlingFile` (`fsList` uses a zone-changes
   fetch and `fsRead`/`fsDelete` fetch by record ID).
4. **Deploy Schema Changes…** to Production. Confirm the Production schema
   lists the same types and fields.

**Expected:** Production has `SeedlingFile {name: String, data: Asset}`. A
Release build
never logs "Cannot create new type … in production schema".

### 1.2 First enable on device A

1. Fresh install of the Release build on iPhone A. Add three memories: a line,
   a photo, a voice memo.
2. Settings → Cloud sync (optional) → on. Sync provider: iCloud. Set a sync
   passphrase. Turn Cloud sync on in the sync tile.
3. Wait for "Up to date".
4. CloudKit Console → **Production** → Records → zone `SeedlingSync`, query
   `SeedlingFile`.

**Expected:** a zone `SeedlingSync` exists; it holds one
`seedling_sync_log_<deviceId>_…` file, one keyring file, and one
`seedling_media_<uuid>.bin` per photo/voice memo. Downloading any file
shows ciphertext (no readable memory text). No records appear in the default
zone.

### 1.3 Second device, right and wrong passphrase

1. iPhone B, same iCloud account, fresh install. Enable sync with a **wrong**
   passphrase.
2. Then enter the right passphrase.

**Expected:** the wrong passphrase is rejected with a calm message and
nothing is stored or uploaded. With the right one, all three memories arrive;
the photo and voice memo show a placeholder first, then download in the
background and play/display correctly.

### 1.4 Edits, deletes, offline

1. On A: edit the line's text. On B: soft-delete the photo. Sync both.
2. Put B in Airplane Mode, edit a memory, re-enable network, sync.
3. On A: permanently delete a memory from Recently Deleted.

**Expected:** each change appears on the other device after its next sync.
The deleted photo does not come back. The offline edit arrives. The permanent
delete removes the memory on B and its `seedling_media_…` file disappears
from the zone.

### 1.5 Changed passphrase and quarantine notice

1. On A, change the sync passphrase (Settings → Privacy → Sync passphrase),
   add a memory, sync.
2. Sync B without re-entering the passphrase.
3. Re-enter the new passphrase on B and sync again.

**Expected:** at step 2 B imports nothing unreadable. It either reports that
the sync key needs refreshing ("Re-enter your sync passphrase…", from the
keyring key check) or, for individual records it can't decrypt, its sync tile
shows "N changes from another device couldn't be read — re-enter your
passphrase on that device." in secondary (not red) text with a 44 pt "Why?"
button that shows a short reassurance. After step 3 the message/notice is gone
and the memory arrives. The notice also appears on iOS (it is no longer an
Android-only Drive badge) and has no "Clear" button: set-aside changes are
retried on every pull.

---

## 2. Keychain accessibility (iOS)

Every secret is written with `first_unlock_this_device`
(`createSeedlingSecureStorage()`); there is no migration.

1. Fresh install. Add memories, turn on app lock, set a sync passphrase,
   create a capsule.
2. Force-quit, relaunch, unlock with Face ID.
3. Restart the phone; before unlocking it, wait for a scheduled reminder or
   widget refresh; then unlock and open the app.

**Expected:** every memory is readable (no blank or ciphertext text), the
capsule stays sealed, sync continues without asking for the passphrase, and
nothing crashes after a restart. Share diagnostics (Settings → About)
contains no keychain errors.

## 3. Backup exclusion

### iOS

1. With memories and media on the device, run an iCloud backup (Settings →
   [name] → iCloud → iCloud Backup → Back Up Now), or an encrypted Finder
   backup.
2. Erase a test device and restore it from that backup. Open Seedling.

**Expected:** Seedling opens with an empty tree (onboarding or empty state),
not with the old memories and not with a crash or a "can't decrypt" state.
Settings → Privacy shows "Keeping a copy". If sync was on, the restored
install gets a new sync device id and pulls everything again once the
passphrase is re-entered. In Settings → General → iPhone Storage → Seedling,
the backed-up size is small (no `database/` or `media/`).

### Android

1. `adb shell bmgr backupnow com.twotwoeightthreelabs.seedling`.

**Expected:** no Seedling data is backed up (`allowBackup="false"`,
`data_extraction_rules`). A device-to-device transfer does not bring memories
along.

## 4. iOS widget: privacySensitive and calm mode

1. Add the small, medium and large Seedling widgets to the Home Screen and the
   medium one to the Lock Screen / Today view.
2. Settings → Privacy: turn on widget memory previews (app lock off).
3. Lock the phone and look at the Lock Screen and StandBy.
4. Turn app lock on.
5. Settings → Your tree: turn calm mode on, go back to the Home Screen.

**Expected:**
- Step 2: the "Latest" memory text shows on the unlocked Home Screen.
- Step 3: on the locked device the memory text is redacted (placeholder bars);
  tree emoji and counts stay.
- Step 4: memory text is not written to the widget at all (previews are off
  while app lock is on).
- Step 5: entry count, stage name and progress bar disappear from every size
  ("Your tree" instead of the stage name). Turning calm mode off brings them
  back after the next widget refresh.

Repeat step 5 on Android (small and medium widgets): count and progress views
are hidden.

## 5. Android notification visibility

1. Android with a secure lock screen. Settings (Android) → Notifications → Lock
   screen → "Hide sensitive content".
2. In Seedling: Settings → Prompts → turn on the weekly "From your tree" nudge
   and Gentle reminders. To fire them quickly, set the device clock to Sunday
   09:59 (the nudge is Sunday 10:00) or temporarily lower the reminder time.
3. Lock the phone and wait.

**Expected:** the resurfacing nudge shows only "Contents hidden" on the lock
screen (channel "Memories from your tree", `visibility: private`); unlocked, it
reads "A memory is waiting for you". Gentle reminders show their generic
copy ("A gentle check-in"). No notification ever contains memory text, a
title or a date. On iOS both are passive (no sound, no banner wake).

## 6. Deep linking disabled

1. From another app or Safari / Chrome, open `seedling://x/settings/deleted`,
   `seedling://x/entry/1` and `seedling://x/settings`.
2. Open `seedling://capture` and `seedling://home` the same way, and tap the
   widget's capture button.
3. Turn on app lock, kill the app, tap the widget's capture button.

**Expected:** step 1 only opens the app on its current screen; it never
navigates to the route. Step 2 opens the capture sheet / home screen. Step 3
shows the lock screen first; the capture sheet opens only after unlocking.

## 7. Share intake path fix (Android)

1. Share a photo from Google Photos and from Files to Seedling.
2. Share a file from an app whose provider reports a display name with `../`
   (use a small test app or `adb shell am start -a android.intent.action.SEND
   -t image/jpeg --eu android.intent.extra.STREAM content://…` from a test
   provider returning `_display_name = ../../shared_prefs/x.xml`).
3. `adb shell run-as com.twotwoeightthreelabs.seedling ls -R cache/shared_intake shared_prefs`.

**Expected:** steps 1–2 show the confirm sheet; nothing is saved until you
confirm. Files land only in `cache/shared_intake/` as `IMG_<uuid>.<ext>`; no
file outside it is created or overwritten. An hour later (next launch) the
intake copies are swept.

## 8. On-device transcription (iOS)

1. iPhone with on-device speech for the current language (Settings → General
   → Keyboard → Dictation languages, downloaded). Record a voice memo.
2. Open it → Transcribe. Allow speech recognition.
3. Turn on Airplane Mode and transcribe another memo.
4. Switch the device language to one without on-device support and try again.

**Expected:** steps 2–3 produce a transcription with no network (Airplane Mode
works). Step 4 shows "On-device transcription is not available on this
device" and never sends audio to a server. Android shows no Transcribe button
(or reports unavailable).

## 9. Reduce Motion

Turn on Reduce Motion (iOS: Accessibility → Motion; Android: Remove
animations) and check:

| Where | Expected |
| --- | --- |
| Home tree | No idle sway; growth swaps in place; no sparkle burst (haptic still plays) |
| Capsule unlock | Crossfade, no shake/scale/sparkles |
| Release ceremony ("Let go") | Plain fade instead of drifting leaves |
| Onboarding | Panels and dots appear without animating |
| Prompt card | No slide-in |
| Memory reader | Page changes jump instead of sliding |
| Toasts (iOS) | Appear without sliding |

## 10. VoiceOver (iOS) and TalkBack (Android)

### Capture sheet

1. Open capture from the home screen with the screen reader on.
2. Navigate every control in order; type a line; attach a photo; try to add a
   voice memo (expect the replace prompt); use Let go, Ritual and Capsule.
3. Start and stop recording with a double-tap (not a hold).
4. Save.

**Expected:** focus starts in the text field; every button has a spoken label
and the selected entry-type button is announced as selected; the mic can be
started and stopped by double-tap; the "replace photo with voice memo?" prompt
is reachable and readable; "Save memory" / "Seal capsule" is announced and a
confirmation is spoken. Nothing behind the sheet is reachable.

### Reader and detail

1. Open a memory, then the reader (swipe through memories).
2. Navigate edit, delete, share, close and next/previous.
3. Turn on app lock, background and return.

**Expected:** the reader chrome stays visible while a screen reader runs;
every control is labelled and ≥ 44 pt; Android edit/delete have tooltips;
photos and voice memos have meaningful labels. While locked, nothing behind
the lock screen is focusable or read.

Also check at the largest Dynamic Type / font size that memory cards, the
sync quarantine notice and the capture sheet wrap without clipping.

## 11. Large export on device

1. Seed a device with ~2,000 memories including ~300 photos and ~50 voice
   memos (import a prepared ZIP, or use a script against a debug build).
2. Export as ZIP, Markdown and Encrypted Backup. Watch memory use in Xcode
   Instruments / Android Studio profiler.
3. Import each file on a second, empty device.
4. Repeat with a set above the limits (e.g. > 800 MB of media).

**Expected:** each export finishes without the UI freezing or the app being
killed for memory; the share sheet opens; the temp file is deleted after the
share sheet closes. Imports show a preview with counts and then restore every
memory and media file. Over the limits, export stops before reading media with
"Nothing was lost. Try …" instead of producing a file restore can't read. If
some media is still downloading from sync, export first offers Wait / Export
anyway.

## 12. Day One real export import

1. In Day One, export a real journal as JSON (ZIP) that contains: plain
   entries, entries with one photo, several photos, an audio recording, tags,
   a starred entry, a location, and a video or PDF.
2. Settings → Data → Import from Day One / Markdown → pick the ZIP.
3. Confirm the preview, import, then import the same ZIP again.

**Expected:** the preview counts match the journal; text has no
`dayone-moment://` references or stray Markdown escapes; a leading heading
becomes the title; tags are kept (starred → "starred" tag); the place is in
context; one photo → a photo memory; several media → the first carries the
text and each further item is its own memory titled "<title> - 2 of 3";
videos/PDFs produce a warning only. The second import adds nothing (all
skipped as already in Seedling). The `seedling_import_*` staging folder is
gone afterwards.

Repeat with a Seedling Markdown export that has been opened and re-saved in
Obsidian: memories round-trip with their media.

## 13. Encrypted database (SQLCipher)

The database is `<Documents>/database/seedling.db` (+ `-wal`, `-shm`),
encrypted as a whole by SQLCipher, which `package:sqlite3`'s build hook
links on each platform (`hooks.user_defines.sqlite3.source: sqlcipher` in
`pubspec.yaml`). Host tests prove the Dart side; only a device proves the
native library made it into the app.

1. Fresh install of a Release build on iOS and on Android. Add a memory with
   a distinctive word (for example `zebrafinch`).
2. Settings → About → Share diagnostics: no `DatabaseOpenException` and no
   `SQLCipher is not linked` entry.
3. Copy the file off the device: iOS via Xcode → Devices → Download
   Container (a debug or development-signed build); Android via
   `adb exec-out run-as com.twotwoeightthreelabs.seedling cat app_flutter/database/seedling.db > seedling.db`
   (debuggable build). Run `strings seedling.db | grep -i -e zebrafinch -e "SQLite format"`
   and `sqlite3 seedling.db .tables`.
4. Force-quit and relaunch; restart the phone and open the app after unlock.
5. iOS: confirm the build log / app bundle contains the SQLCipher library
   (`Frameworks/` holds the `sqlite3` native asset; `otool -L Runner` or the
   framework's symbols include `sqlcipher_`), and that no other SQLite
   (for example a pod linking the system `libsqlite3`) is loaded first.
   Android: `unzip -l app-release.apk | grep -i sqlite` shows the bundled
   library for every ABI, and the APK carries OpenSSL's `libcrypto` for the
   SQLCipher build.

**Expected:** the app opens normally and memories are readable after each
relaunch and restart. The copied file contains neither the word nor the
`SQLite format 3` header, and the `sqlite3` CLI reports "file is not a
database". The Keychain / Keystore holds the item `seedling_database_key_v1`
(device-only); nothing else about the database is in preferences.
