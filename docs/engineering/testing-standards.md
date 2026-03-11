# Testing Standards

## Unit Test Requirements
1. Every service module must have a corresponding `test/services/*_test.dart` file.
2. Tests must cover success paths, failure paths, and edge cases.
3. Time-based behavior (debounce, retries) must be tested deterministically.
4. Sorting/scoring logic must assert stable ordering and tie behavior.
5. New bug fixes require at least one regression test.

## Integration and Manual Validation
1. Device permissions and platform channels must be validated on iOS and Android devices/simulators.
2. iCloud/CloudKit sync requires multi-device validation.
3. Accessibility checks must include VoiceOver/TalkBack walkthroughs.

## Coverage and CI
1. CI must run `flutter test` on every PR.
2. CI should collect coverage and block regressions for touched modules.
3. Analyzer and formatter checks are mandatory before merge.
