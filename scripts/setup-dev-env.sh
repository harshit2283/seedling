#!/bin/bash
# Seedling Development Environment Setup
# Run this script to install Flutter SDK and Android SDK for building APKs.
# iOS/IPA builds require macOS with Xcode — not possible on Linux.
#
# Usage:
#   chmod +x scripts/setup-dev-env.sh
#   ./scripts/setup-dev-env.sh
#
# After running, add to your shell profile (~/.bashrc or ~/.zshrc):
#   source /home/user/seedling/scripts/env.sh

set -euo pipefail

FLUTTER_DIR="/opt/flutter"
ANDROID_SDK_DIR="/opt/android-sdk"
CMDLINE_TOOLS_VERSION="11076708"

echo "=== Seedling Dev Environment Setup ==="

# ---- Java (required by Android SDK) ----
if ! command -v java &>/dev/null; then
  echo "[1/5] Installing OpenJDK 21..."
  sudo apt-get update -qq
  sudo apt-get install -y openjdk-21-jdk-headless
else
  echo "[1/5] Java already installed: $(java -version 2>&1 | head -1)"
fi

# ---- Flutter SDK ----
if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "[2/5] Flutter already installed at $FLUTTER_DIR"
else
  echo "[2/5] Installing Flutter SDK..."
  curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.4-stable.tar.xz" -o /tmp/flutter.tar.xz
  sudo tar xf /tmp/flutter.tar.xz -C /opt/
  rm -f /tmp/flutter.tar.xz
  git config --global --add safe.directory "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics 2>/dev/null || true
dart --disable-analytics 2>/dev/null || true

echo "  Flutter: $(flutter --version 2>&1 | head -1)"
echo "  Dart:    $(dart --version 2>&1)"

# ---- Upgrade Flutter (if Dart SDK < 3.10.7) ----
DART_VERSION=$(dart --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
REQUIRED_DART="3.10.7"
if printf '%s\n' "$REQUIRED_DART" "$DART_VERSION" | sort -V | head -1 | grep -q "$REQUIRED_DART"; then
  echo "  Dart $DART_VERSION satisfies ^$REQUIRED_DART"
else
  echo "  Dart $DART_VERSION too old, upgrading Flutter..."
  flutter upgrade --force
fi

# ---- Android SDK ----
if [ -d "$ANDROID_SDK_DIR/cmdline-tools/latest" ]; then
  echo "[3/5] Android cmdline-tools already installed"
else
  echo "[3/5] Installing Android command-line tools..."
  sudo mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
  curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/cmdline-tools.zip
  unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extract
  mv /tmp/cmdline-tools-extract/cmdline-tools "$ANDROID_SDK_DIR/cmdline-tools/latest"
  rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extract
fi

export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
export PATH="$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$PATH"

# ---- Android SDK packages ----
echo "[4/5] Installing Android SDK packages (build-tools, platform)..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager --install \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  2>&1 | grep -v "^\[" | tail -5

# ---- Flutter doctor ----
echo "[5/5] Running flutter doctor..."
flutter doctor --android-licenses 2>/dev/null <<< "y
y
y
y
y
y
y
y" || true

flutter config --android-sdk "$ANDROID_SDK_DIR" 2>/dev/null || true

echo ""
echo "=== Setup Complete ==="
flutter doctor -v 2>&1 | grep -E "Flutter|Dart|Android|Java" | head -10
echo ""
echo "Run 'source scripts/env.sh' to set environment variables."
echo "Then: flutter build apk --debug"
