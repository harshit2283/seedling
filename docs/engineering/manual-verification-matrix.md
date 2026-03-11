# Manual Verification Matrix

## iOS
1. Onboarding cold install redirects to `/onboarding` and completion persists.
2. Home screen renders without bottom inset artifacts.
3. Quick capture can save line/photo/voice/object/capsule flows.
4. Export share sheet opens without `sharePositionOrigin` exception.
5. Voice transcription works on real device.
6. VoiceOver reads primary controls and list cards correctly.
7. iCloud sync pull/push works across two devices.

## Android
1. Onboarding cold install flow works.
2. Camera/microphone/gallery permissions requested correctly.
3. Quick capture save flows work for all entry types.
4. Memory reader fallback navigation works.
5. Sync status tile reflects enabled/disabled and last sync state.
6. Release build succeeds with signing env vars.

## Cross-platform
1. Capsules stay hidden from all-memories feed and visible in capsules screen.
2. Year-in-review appears only when entry threshold is met.
3. Import/export encrypted backup roundtrip succeeds.
4. App lock via device auth gates protected flows.
