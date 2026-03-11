# Repository Structure

## Top-Level
1. `lib/` application code.
2. `test/` automated tests.
3. `docs/` engineering and product documentation.
4. `ios/` and `android/` platform code.
5. `.github/workflows/` CI pipelines.

## Application Layers
1. `lib/features/*` UI and feature-level state only.
2. `lib/core/services/*` shared domain/platform services.
3. `lib/data/*` models and persistence.
4. `lib/app/*` app bootstrap, routing, theming.

## Naming Conventions
1. Provider files end with `_provider.dart` or contain `*Provider` declarations.
2. Service files end with `_service.dart`.
3. Test files mirror source location and end with `_test.dart`.
