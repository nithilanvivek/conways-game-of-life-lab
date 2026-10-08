#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
OUTPUT_DIR="$REPO_DIR/dist/android"

"$SCRIPT_DIR/build-signed-apks.sh"
cp "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-2.0-signed.apk" "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-2.0.apk"
cp "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-2.0-ChromeOS-signed.apk" "$OUTPUT_DIR/Conways-Game-Of-Life-Lab-2.0-ChromeOS.apk"

(
    cd "$OUTPUT_DIR"
    shasum -a 256 \
        Conways-Game-Of-Life-Lab-2.0.apk \
        Conways-Game-Of-Life-Lab-2.0-ChromeOS.apk
        > SHA256SUMS.txt
)

echo "Built release-signed website APKs in $OUTPUT_DIR"
