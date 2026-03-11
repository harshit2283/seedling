# Coding Standards

## Scope
These standards apply to all production code in `lib/`, platform code in `ios/` and `android/`, and tests in `test/`.

## Dart and Flutter
1. Use `snake_case` for file names, `PascalCase` for classes, and `camelCase` for members.
2. Explicit return types are required for all public and private methods except local closures.
3. Mark locals and fields `final` unless mutation is required.
4. Never use `print` in app or test code; use structured logging or `debugPrint` in non-production tooling only.
5. Do not use `BuildContext` after async gaps without a `mounted` guard.
6. Avoid broad `catch (e)` blocks. Catch typed exceptions first and map them to domain errors.
7. Service APIs should return typed result objects, not mixed bool/string/null contracts.
8. Keep widget build methods presentation-only; move filtering/transforms into providers/services.
9. Keep comments brief and rationale-oriented. Do not describe obvious code.

## Architecture and Imports
1. `features/*` can depend on `core/*` and `data/*` but not other feature internals.
2. Shared business logic belongs in `core/services` or `data/*`, not inside widgets.
3. Providers are the only entrypoint to service and database access from UI layers.
4. Avoid cyclic dependencies. Extract interfaces/types when boundaries are unclear.

## Platform Code
1. Swift and Kotlin must surface stable error codes/messages over platform channels.
2. Avoid force unwraps (`!`) in Swift production code.
3. Handle nullability explicitly in Kotlin.
4. Keep iOS and Android channel method names and payload shapes aligned with Dart wrappers.

## Reliability
1. New behavior must include unit tests.
2. Regression fixes must include a reproducer test first where feasible.
3. Feature flags and defaults must be explicit and documented.
