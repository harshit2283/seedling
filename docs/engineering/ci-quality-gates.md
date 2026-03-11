# CI Quality Gates

Every pull request must pass all gates:
1. Format check: `dart format --output=none --set-exit-if-changed .`
2. Static analysis: `flutter analyze`
3. Automated tests: `flutter test`

## Required Reviewer Checklist
1. No analyzer warnings/errors in modified modules.
2. New/changed logic has tests.
3. iOS and Android manual checks are documented for platform-sensitive changes.
4. Migration notes are included for schema or sync changes.
