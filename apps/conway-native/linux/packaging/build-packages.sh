#!/usr/bin/env bash
# Build native Conway packages on Ubuntu 24.04. Never touches user data.
set -euo pipefail
LINUX_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT_DIR=${1:?Pass an output directory}
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
VERSION=3.0
case $(uname -m) in
  x86_64)
    TOOL_ARCH=x86_64; FILE_ARCH=x86_64; DEB_ARCH=amd64
    DEPLOY_SHA=8aea8da0f7f7039d2a2cecb14657d752a222a5e1d3825caeef186c82f751cdd1
    PACKAGER_SHA=95cbe7cce9717fce90c484e34052ee7c7f1d7635b33c12525b4776826a7d29b6
    RUNTIME_SHA=156f4bdbde9c52d01814600013e0a273f0118dc2de98975f3c8c63427ec79074
    ;;
  aarch64)
    TOOL_ARCH=aarch64; FILE_ARCH=arm64; DEB_ARCH=arm64
    DEPLOY_SHA=5c1fddf96066891e829831cac0d84424690f3b22846c7f8f1bb9990a5c6c73f4
    PACKAGER_SHA=a595ea34cd6136c7f595e9dcbb16f3e9725d7610efb9e43b38c3c6e86cafc270
    RUNTIME_SHA=b4ff0030242d0c3bb12ce40541828303cf167493f4793456f0436edd6255c39d
    ;;
  *) echo 'Only x86_64 and ARM64 are supported.' >&2; exit 1 ;;
esac
fetch() {
  curl --fail --location --retry 3 "$1" --output "$2"
  printf '%s  %s\n' "$3" "$2" | sha256sum --check
}
mkdir -p "$WORK_DIR/tools/deploy" "$WORK_DIR/tools/packager"
fetch "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$TOOL_ARCH.AppImage" "$WORK_DIR/tools/linuxdeploy.AppImage" "$DEPLOY_SHA"
fetch "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$TOOL_ARCH.AppImage" "$WORK_DIR/tools/appimagetool.AppImage" "$PACKAGER_SHA"
fetch "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-$TOOL_ARCH" "$WORK_DIR/tools/runtime" "$RUNTIME_SHA"
fetch 'https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/7a3fbc31a9e5075073ff8790f26effbac5f84453/linuxdeploy-plugin-gtk.sh' "$WORK_DIR/tools/linuxdeploy-plugin-gtk.sh" b0f4cbc684a0103a9651f0955b635eaea0096b3a66c0f5a2c2aa337960375171
chmod +x "$WORK_DIR/tools/"*.AppImage "$WORK_DIR/tools/linuxdeploy-plugin-gtk.sh"
(cd "$WORK_DIR/tools/deploy"; ../linuxdeploy.AppImage --appimage-extract > /dev/null)
(cd "$WORK_DIR/tools/packager"; ../appimagetool.AppImage --appimage-extract > /dev/null)
make -C "$LINUX_DIR"

# Keep the established DEB package identity so apt upgrades the earlier edition.
DEB_ROOT="$WORK_DIR/deb"
make -C "$LINUX_DIR" install-dist PREFIX=/usr DESTDIR="$DEB_ROOT"
ln -s nithi-life "$DEB_ROOT/usr/bin/conway-life-lab"
mkdir -p "$WORK_DIR/debian" "$DEB_ROOT/DEBIAN"
cat > "$WORK_DIR/debian/control" <<EOF
Source: nithi-land-conway-life-lab
Section: education
Priority: optional
Maintainer: Nithilan Vivek <nithilanvivek@gmail.com>
Standards-Version: 4.7.0

Package: nithi-land-conway-life-lab
Architecture: any
Description: Conway's Game of Life Lab
EOF
DEPS=$(cd "$WORK_DIR"; dpkg-shlibdeps -O "$DEB_ROOT/usr/bin/nithi-life" | sed 's/^shlibs:Depends=//')
cat > "$DEB_ROOT/DEBIAN/control" <<EOF
Package: nithi-land-conway-life-lab
Version: $VERSION
Section: education
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Nithilan Vivek <nithilanvivek@gmail.com>
Installed-Size: $(du -sk "$DEB_ROOT/usr" | cut -f1)
Depends: $DEPS
Homepage: https://nithi.land/projects/conways-game-of-life/
Description: Conway's Game of Life Lab
 Explore cellular life with patterns, editable rules, a live population graph,
 saved canvases, undo and redo, themes and a guided tour.
EOF
mkdir -p "$DEB_ROOT/usr/share/doc/nithi-land-conway-life-lab"
cp "$LINUX_DIR/../LICENSE" "$DEB_ROOT/usr/share/doc/nithi-land-conway-life-lab/copyright"
dpkg-deb --build --root-owner-group "$DEB_ROOT" "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-$VERSION-$DEB_ARCH.deb"

APPDIR="$WORK_DIR/AppDir"
make -C "$LINUX_DIR" install-dist PREFIX=/usr DESTDIR="$APPDIR"
export PATH="$WORK_DIR/tools:$PATH" DEPLOY_GTK_VERSION=3
"$WORK_DIR/tools/deploy/squashfs-root/AppRun" --appdir "$APPDIR" --plugin gtk \
  --desktop-file "$APPDIR/usr/share/applications/land.nithi.life.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/land.nithi.life.png"
# Retain dependency copyright notices, including GTK and its bundled resources.
mkdir -p "$APPDIR/usr/share/licenses/third-party"
for notice in /usr/share/doc/*/copyright; do
  package=$(basename "$(dirname "$notice")")
  cp -L "$notice" "$APPDIR/usr/share/licenses/third-party/$package.txt"
done
dpkg-query -W -f='${binary:Package}\t${Version}\n' > "$APPDIR/usr/share/licenses/third-party/build-environment-packages.txt"
ARCH="$TOOL_ARCH" "$WORK_DIR/tools/packager/squashfs-root/AppRun" --runtime-file "$WORK_DIR/tools/runtime" \
  "$APPDIR" "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-$FILE_ARCH.AppImage"
(cd "$OUTPUT_DIR"; sha256sum "Conways-Game-Of-Life-Lab-$FILE_ARCH.AppImage" "Conways-Game-Of-Life-Lab-$VERSION-$DEB_ARCH.deb" > "SHA256SUMS-$FILE_ARCH.txt")
