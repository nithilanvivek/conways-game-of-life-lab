#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/../../dist/conway-native"
APP="$OUT/Conway's Game of Life Lab-testing.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/swift-cache"
swiftc -O -parse-as-library -module-cache-path "$OUT/swift-cache" -target arm64-apple-macosx14.0 "$ROOT/macos/Engine.swift" "$ROOT/macos/Patterns.swift" "$ROOT/macos/App.swift" -o "$APP/Contents/MacOS/ConwayLifeLab"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ConwayLifeLab</string><key>CFBundleIdentifier</key><string>land.nithi.conwaylifelab.macos</string><key>CFBundleName</key><string>Conway's Game Of Life Lab</string><key>CFBundleDisplayName</key><string>Conway's Game Of Life Lab</string><key>CFBundleVersion</key><string>8</string><key>CFBundleShortVersionString</key><string>3.1</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/><key>CFBundleIconFile</key><string>AppIcon</string><key>NSHumanReadableCopyright</key><string>© 2026 Nithilan Vivek</string>
</dict></plist>
PLIST
ICON="$ROOT/../../assets/downloads/icons/Conways-Game-Of-Life-Lab-Icon-1080.png"
ICONSET="$OUT/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do sips -z "$size" "$size" "$ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null; double=$((size*2)); sips -z "$double" "$double" "$ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null; done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/shared/tour.json" "$APP/Contents/Resources/tour.json"
codesign --force --sign - "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Conways-Game-of-Life-Lab-3.1-macOS-testing.zip"
echo "$APP"
