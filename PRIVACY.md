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
- **Analysis happens on your device.** Themes, connections, and voice
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
Deleting the app removes its local data.

## What the developer receives

Nothing. Seedling has no backend, no telemetry SDK, and no analytics or
advertising libraries. Seedling does not sell, share, or rent data, because
it never has any.

## On-device processing

- **Themes, connections, and suggestions** use keyword matching and the
  platform's on-device language tools (Apple NaturalLanguage on iOS, Google
  ML Kit on Android). Your text is not sent anywhere for analysis.
- **Voice transcription (iOS only)** uses Apple's speech recognizer with
  on-device recognition required. If your device or language can't
  transcribe on-device, Seedling simply doesn't transcribe; it never falls
  back to a server. Transcription is not offered on Android, because the
  Android system recognizer may send audio to a cloud service.

> **Note for Android:** the first time it runs, Google ML Kit downloads its
> language model from Google's servers. No memory content is included in
> that download request, but it is a network connection to Google that
> happens without a separate prompt. See "Known limitations" below.

## Optional cloud sync

Sync is **off by default** and starts only after you turn it on in
Settings and choose a provider:

- **iCloud (iOS):** records go to the private CloudKit database in your own
  iCloud account.
- **Google Drive (Android, optionally iOS):** you sign in with Google, and
  Seedling uses Drive's hidden app-data folder in your own Drive. Seedling
  requests only that app-data scope; it cannot see your other Drive files.

Sync requires a passphrase that you choose. Before anything leaves the
device, the text of each memory (text, title, context, mood, tags,
transcription, detected theme, and links between memories) is encrypted
with a key derived from that passphrase (AES-256-GCM; PBKDF2 with a random
salt unique to your account, stored in your own sync space). The
passphrase itself is never stored, on your devices or anywhere else.
Without it, those fields can't be read by Apple, Google, or us.

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
  dates, capsule unlock dates, deletion state and date, a sentiment score,
  the local media file name, a random media file id, and a random device
  ID are stored unencrypted alongside the encrypted fields, so sync can
  work.
- **Sizes and timing.** Apple or Google can see how many records and media
  files you have, roughly how large each encrypted file is, and when they
  change.

Apple's and Google's handling of data in your account is governed by their
own privacy policies.

## Exports, backups, and sharing

These happen only when you ask:

- **Export** (JSON or ZIP) and **encrypted backup** create files that you
  save or send wherever you choose using the system share sheet.
- **Sharing** a memory or a Year in Review card goes through the system
  share sheet to the app you pick.
- **Receiving shares** from other apps creates a memory only after you
  confirm it.

## Notifications and widgets

- **Gentle reminders** are opt-in and off by default. They are scheduled
  locally; no push service is involved.
- **Home screen widgets** show your tree and counts. Showing memory text in
  widgets is off by default. Widget data is shared only between Seedling
  and its own widget on your device.

## Diagnostics

Seedling does not collect crash reports or diagnostics. Error details are
only printed to the developer console in debug builds. If you report a
bug, you decide what to include.

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
3. On Android, ML Kit may contact Google to download its language model
   on first launch, before any opt-in.

These are tracked as open work.

## Changes

If this policy changes, the new version will be published in the
repository and noted in the release notes. Changes will never introduce
data collection by the developer.

## Contact

Questions: open an issue at
<https://github.com/harshit2283/seedling/issues>, or see
[SECURITY.md](SECURITY.md) to report a security problem privately.
