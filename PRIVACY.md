# Seedling Privacy Policy

_Last updated: 19 October 2026_

Seedling is a private place to keep small memories. This policy is written
in plain language and describes what the app actually does. Seedling is open
source, so every statement here can be checked against the code at
<https://github.com/harshit2283/seedling>.

## The short version

- **The developer collects nothing.** There are no accounts, no analytics,
  no advertising, no crash reporting, and no servers run by Seedling.
- **Your memories stay on your device** unless you choose to move them.
- **Cloud sync is off by default.** If you turn it on, your memories go to
  *your own* iCloud or Google Drive, not to us.
- **Analysis happens on your device.** Themes, related memories, and voice
  transcription are computed locally.

## What Seedling stores, and where

Everything you create (text, photos, voice memos, titles, moods, tags,
capsules, rituals) is stored in the app's private storage on your device.

- The written parts of each memory (text, title, context, mood, tags,
  transcription, themes, and links) are encrypted at rest with a key kept in the
  device's secure storage (iOS Keychain / Android Keystore).
- On iOS, media files use the system's file protection, so they are
  unreadable until you first unlock your phone after a restart.
- Optional app lock uses your device's own Face ID, Touch ID, fingerprint,
  or passcode. Seedling never sees your biometric data.
- Settings (for example whether prompts are on) are kept in ordinary app
  preferences on the device.

Deleted memories go to "Recently Deleted" for 30 days, then are removed.
When you let go of a "Let go" memory and choose "Let it go completely", it is
deleted at once, with its media, without passing through Recently Deleted.
Deleting the app removes its local data.

**Device backups don't include your memories.** On iOS the database and
media folders are excluded from iCloud and computer backups, and the key that
decrypts the database is stored "this device only", so it is never in a
backup. On Android, app backup is turned off. To keep a copy, use Export or
cloud sync.

## What the developer receives

Nothing. Seedling has no backend, no telemetry SDK, and no analytics or
advertising libraries. Seedling does not sell, share, or rent data, because
it never has any.

## On-device processing

- **Themes and related memories** are computed by Seedling's own code on
  your device (a weighted word list and text similarity over your own
  memories). No platform ML service or model download is involved, and your
  text is not sent anywhere for analysis. Seedling does not score how your
  memories feel.
- **Voice transcription (iOS only)** uses Apple's speech recognizer with
  on-device recognition required. If your device or language can't
  transcribe on-device, Seedling simply doesn't transcribe; it never falls
  back to a server. Transcription is not offered on Android, because the
  Android system recognizer may send audio to a cloud service.

## Optional cloud sync

Sync is **off by default** and starts only after you turn it on in
Settings and choose a provider:

- **iCloud (iOS):** encrypted sync files go to a private zone of the
  CloudKit database in your own iCloud account.
- **Google Drive (Android, optionally iOS):** you sign in with Google, and
  Seedling uses Drive's hidden app-data folder in your own Drive. Seedling
  requests only that app-data scope; it cannot see your other Drive files.

Sync requires a passphrase that you choose. Before anything leaves the
device, the text of each memory (text, title, context, mood, tags,
transcription, detected theme, and links between memories) is encrypted
with a key derived from that passphrase (AES-256-GCM; PBKDF2 with a random
salt unique to your account, stored in your own sync space). The
passphrase itself is never stored, on your devices or anywhere else.
Without it, those fields can't be read by Apple, Google, or us. Your sync
space also holds an encrypted check value, so a mistyped passphrase on a
new device is rejected instead of silently producing unreadable data.
Each encrypted field is bound to its memory, and every synced record
(including the unencrypted metadata listed below) carries an
authentication code, so the storage provider can't alter, swap or forge
records without detection. Records that fail these checks are set aside,
not imported.

**Photos, voice memos, and object photos sync end-to-end encrypted.** Each
file is encrypted on your device with its own random key (AES-256-GCM,
in authenticated chunks) before upload, and that key travels only inside
the encrypted memory record. Apple and Google store only ciphertext. On
your other devices the file is downloaded in the background after the
memory arrives (a placeholder shows until then), checked for tampering,
and saved under a new local name. Deleting a memory permanently, or
letting it expire from Recently Deleted, also deletes its encrypted file.
Files larger than 50 MB are not synced.

What sync does **not** encrypt end-to-end:

- **Record metadata** such as memory type, creation and modification
  dates, capsule unlock dates, deletion state and date, a legacy sentiment
  score (only on memories from older versions; Seedling no longer computes
  one),
  the local media file name, a random media file id, and a random device
  ID are stored unencrypted alongside the encrypted fields, so sync can
  work. They are authenticated (tampering is detected) but readable by the
  storage provider.
- **Sizes and timing.** Apple or Google can see how many records and media
  files you have, roughly how large each encrypted file is, and when they
  change.

Apple's and Google's handling of data in your account is governed by their
own privacy policies.

## Exports, backups, and sharing

These happen only when you ask:

- **Export** (JSON, ZIP, or Markdown) and **encrypted backup** create files
  that you save or send wherever you choose using the system share sheet.
  The temporary file is deleted once the share sheet closes. JSON, ZIP and
  Markdown exports are not encrypted; the encrypted backup is protected by a
  password you choose.
- **Import** (an encrypted backup, a Seedling ZIP or Markdown export, or a
  Day One JSON export) reads only the file you pick, on your device, and
  shows what it will add before adding anything.
- **Sharing** a memory or a Year in Review card goes through the system
  share sheet to the app you pick.
- **Receiving shares** from other apps creates a memory only after you
  confirm it.

## Notifications and widgets

- **Gentle reminders** and the weekly **"From your tree"** nudge are opt-in
  and off by default. They are scheduled locally; no push service is
  involved. Their text is generic ("A memory is waiting for you") and never
  includes memory text, titles, or dates; on Android they are marked
  private, so a secure lock screen shows only "Contents hidden".
- **Home screen widgets** show your tree and counts (calm mode hides the
  counts). Showing memory text in widgets is off by default, is turned off
  while app lock is on, and on iOS is redacted while the device is locked.
  Widget data is shared only between Seedling and its own widget on your
  device.

## Diagnostics

Seedling does not collect crash reports or diagnostics. It keeps a small
error log **on your device** (the last 200 errors), redacted before it is
written: quoted text, file paths, links, and email addresses are removed and
messages are shortened, so memory content doesn't end up in it. Nothing is
sent anywhere. If you choose Settings > About > Share diagnostics, Seedling
asks first and then opens the share sheet; you decide where it goes.

## Permissions

Seedling asks for camera, photo library, microphone, speech recognition
(iOS), notifications, and biometrics only when you use the feature that
needs them. Each is optional.

## Children

Seedling does not knowingly collect information from anyone, including
children, because it collects no information at all.

## Known limitations

Being honest about where the code doesn't yet match the ideal:

1. Some sync metadata (dates, type, sentiment score, media file name and
   id) is not encrypted, and encrypted media sizes are visible to the
   storage provider.
2. Media files over 50 MB are not synced.

These are tracked as open work.

## Changes

If this policy changes, the new version will be published in the
repository and noted in the release notes. Changes will never introduce
data collection by the developer.

## Contact

Questions: open an issue at
<https://github.com/harshit2283/seedling/issues>, or see
[SECURITY.md](SECURITY.md) to report a security problem privately.
