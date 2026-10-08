#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
REPOSITORY_ROOT=${PROJECT_DIR:h:h}
PROJECT="$PROJECT_DIR/ConwaysGameOfLifeLab.xcodeproj"
DERIVED_DATA="$REPOSITORY_ROOT/dist/ios/DerivedData"
IPA_PATH="$REPOSITORY_ROOT/dist/ios/Conways-Game-Of-Life-Lab-2.0-dev.ipa"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/ConwaysGameOfLifeLab.app"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the Personal Team identifier shown by Xcode.}"
: "${DEVICE_UDID:?Set DEVICE_UDID to the connected iPad identifier shown by Xcode.}"

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

xcodebuild \
  -project "$PROJECT" \
  -scheme ConwaysGameOfLifeLab \
  -configuration Debug \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  build

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/conway-life-lab-ipa.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$STAGING_DIR/Payload" "${IPA_PATH:h}"
ditto "$APP_PATH" "$STAGING_DIR/Payload/ConwaysGameOfLifeLab.app"
(
  cd "$STAGING_DIR"
  ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_PATH"
)

unzip -t "$IPA_PATH"
print "Created $IPA_PATH"
