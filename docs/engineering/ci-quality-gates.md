# CI Quality Gates

Every pull request must pass all gates:
1. Format check: `dart format --output=none --set-exit-if-changed .`
2. Static analysis: `flutter analyze`
3. Palette check: `bash scripts/check_palette.sh` (no hard-coded light-only
   colors in `lib/features`; use `context.palette`)
4. Automated tests: `flutter test`. Database tests open real SQLCipher files
   (package:sqlite3 bundles SQLCipher, also for host tests); nothing to install

CI (`.github/workflows/quality.yml`) pins Flutter **3.47.7** and caches the
SDK; a newer push to the same branch or PR cancels the older run. Bump the
pin deliberately, in its own PR.

Golden tests (`test/features/tree_illustration_golden_test.dart`) contain no
text, allow 0.5% pixel difference and run only on Linux, where the goldens
are generated. Regenerate on Linux with the pinned Flutter:
`flutter test --update-goldens test/features/tree_illustration_golden_test.dart`.

Things CI cannot check (native code, OS integration, assistive tech) are in
[docs/release/device-verification.md](../release/device-verification.md).

## Required Reviewer Checklist
1. No analyzer warnings/errors in modified modules.
2. New/changed logic has tests.
3. iOS and Android manual checks are documented for platform-sensitive changes.
4. Schema or sync format changes edit version 1 in place (no migrations until
   the first release).
