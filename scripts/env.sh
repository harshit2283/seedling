#!/usr/bin/env bash
# Seedling development environment variables
# Source this file in your shell: source scripts/env.sh

export FLUTTER_DIR="/opt/flutter"
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"

# Verify
echo "Flutter: $(flutter --version 2>&1 | head -1)"
echo "Dart:    $(dart --version 2>&1)"
echo "Java:    $(java -version 2>&1 | head -1)"
echo "Android: $ANDROID_HOME"
