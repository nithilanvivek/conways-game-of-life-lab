#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PREFIX=${LIFE_PREFIX:-"$HOME/.local"}
install -d "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/icons/hicolor/256x256/apps"
binary_tmp=$(mktemp "$PREFIX/bin/.nithi-life.XXXXXX")
trap 'rm -f "$binary_tmp"' EXIT HUP INT TERM
install -m 755 "$ROOT/nithi-life" "$binary_tmp"
mv -f "$binary_tmp" "$PREFIX/bin/nithi-life"
trap - EXIT HUP INT TERM
install -m 644 "$ROOT/app-icon.png" "$PREFIX/share/icons/hicolor/256x256/apps/land.nithi.life.png"
cat > "$PREFIX/share/applications/land.nithi.life.desktop" <<EOF_DESKTOP
[Desktop Entry]
Type=Application
Name=Conway’s Game of Life Lab
Comment=Conway's Game of Life — a native canvas for discovery
Exec="$PREFIX/bin/nithi-life"
Icon=land.nithi.life
Terminal=false
Categories=Education;Science;Simulation;
StartupWMClass=nithi-life
EOF_DESKTOP
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$PREFIX/share/applications"; fi
printf 'Installed to %s/bin/nithi-life\n' "$PREFIX"
