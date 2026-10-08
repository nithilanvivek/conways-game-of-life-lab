#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
"$REPO/apps/android/gradlew" -p "$ROOT/chromeos" :app:assembleDebug :app:lintDebug
mkdir -p "$REPO/dist/conway-native"
cp "$ROOT/chromeos/app/build/outputs/apk/debug/app-debug.apk" "$REPO/dist/conway-native/Conways-Game-of-Life-Lab-3.1-ChromeOS-testing.apk"
