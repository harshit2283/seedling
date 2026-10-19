#!/usr/bin/env bash
# Fails when feature widgets hard-code light-only colors instead of reading
# the adaptive palette (`context.palette`, lib/app/theme/palette.dart).
#
# Flagged: SeedlingColors.text*, SeedlingColors.forestGreen, Colors.white,
# Colors.black anywhere under lib/features.
# Allowed: files in ALLOWLIST below, and any line ending in `// palette: allow`.
#
# The same rule runs inside `flutter test` (test/app/palette_usage_test.dart).
set -euo pipefail

cd "$(dirname "$0")/.."

ALLOWLIST=(
  # Procedural tree painter: white highlights are part of the artwork.
  "lib/features/tree/presentation/animated_tree_visualization.dart"
  # Full-screen photo viewer is always black, like the system Photos app.
  "lib/features/memories/presentation/widgets/photo_viewer.dart"
)

pattern='SeedlingColors\.(text[A-Za-z]*|forestGreen\b)|Colors\.(white|black)'
exclude_args=()
for f in "${ALLOWLIST[@]}"; do
  exclude_args+=(--exclude="$(basename "$f")")
done

hits=$(grep -rnE "$pattern" lib/features --include='*.dart' "${exclude_args[@]}" \
  | grep -v '// palette: allow' || true)

if [[ -n "$hits" ]]; then
  echo "Hard-coded colors found in lib/features. Use context.palette instead:"
  echo "$hits"
  exit 1
fi
echo "Palette check passed."
