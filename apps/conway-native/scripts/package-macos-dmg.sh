#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo 'Usage: package-macos-dmg.sh <approved.app> <output.dmg>' >&2
  exit 2
fi
APP="$1"
OUT="$2"
test -d "$APP/Contents"
if [ -e "$OUT" ]; then
  echo "Output already exists: $OUT" >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/conway-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
codesign --verify --deep --strict "$STAGE/$(basename "$APP")"
hdiutil create -volname "Conway's Game Of Life Lab" -srcfolder "$STAGE" -format UDZO -imagekey zlib-level=9 "$OUT"
hdiutil verify "$OUT"
