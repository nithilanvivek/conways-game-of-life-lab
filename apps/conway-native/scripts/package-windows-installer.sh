#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo 'Usage: package-windows-installer.sh <approved.exe> <output.exe>' >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAYLOAD="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
test -f "$PAYLOAD"
command -v makensis >/dev/null
makensis -V3 "-DPAYLOAD=$PAYLOAD" "-DOUTPUT=$OUT" "-DNOTICES=$ROOT/windows/notices" "$ROOT/windows/installer.nsi"
