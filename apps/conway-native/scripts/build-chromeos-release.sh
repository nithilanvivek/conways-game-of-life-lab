#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
CURRENT_ACCOUNT=$(id -un)
ACCOUNT_HOME=$(dscl . -read "/Users/$CURRENT_ACCOUNT" NFSHomeDirectory | awk '{print $2}')
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$ACCOUNT_HOME/Library/Android/sdk}"
export NITHI_ANDROID_KEYSTORE="${NITHI_ANDROID_KEYSTORE:-$ACCOUNT_HOME/.android/release-keys/nithi-land-release.p12}"
if [ -z "${NITHI_ANDROID_STORE_PASSWORD:-}" ]; then
    NITHI_ANDROID_STORE_PASSWORD=$(security find-generic-password -a nithi.land -s land.nithi.android-release -w)
fi
export NITHI_ANDROID_STORE_PASSWORD
export NITHI_ANDROID_KEY_PASSWORD="${NITHI_ANDROID_KEY_PASSWORD:-$NITHI_ANDROID_STORE_PASSWORD}"
export NITHI_ANDROID_KEY_ALIAS="${NITHI_ANDROID_KEY_ALIAS:-nithi-land-release}"
"$REPO/apps/android/gradlew" -p "$ROOT/chromeos" :app:assembleRelease :app:lintRelease -PlifeTestBuildType=release :app:assembleReleaseAndroidTest
unset NITHI_ANDROID_STORE_PASSWORD NITHI_ANDROID_KEY_PASSWORD
mkdir -p "$REPO/dist/conway-native/final/ChromeOS"
cp "$ROOT/chromeos/app/build/outputs/apk/release/app-release.apk" "$REPO/dist/conway-native/final/ChromeOS/Conways-Game-Of-Life-Lab-3.0-ChromeOS.apk"
echo 'Built release-signed ChromeOS APK; verify with apksigner before publishing.'
