#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
OUT="$REPO/tmp/conway-native-tests"
mkdir -p "$OUT/swift-cache" "$OUT/java"
cc -std=c11 -Wall -Wextra -Wno-unused-function -fsanitize=address,undefined "$ROOT/tests/engine-c.c" -o "$OUT/engine-c"
"$OUT/engine-c"
swiftc -Onone -parse-as-library -module-cache-path "$OUT/swift-cache" "$ROOT/macos/Engine.swift" "$ROOT/macos/Patterns.swift" "$ROOT/tests/engine-swift.swift" -o "$OUT/engine-swift"
"$OUT/engine-swift" "$OUT/swift.life.json"
DOTNET_CLI_HOME="$REPO/tmp/dotnet" NUGET_PACKAGES="$REPO/tmp/nuget" DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet run --no-restore --project "$ROOT/tests/dotnet/EngineTests.csproj" -- "$OUT/swift.life.json" "$OUT/dotnet.life.json"
"$OUT/engine-swift" "$OUT/swift.life.json" "$OUT/dotnet.life.json"
JAVA_RUNTIME=${JAVA_HOME:-"/Applications/Android Studio.app/Contents/jbr/Contents/Home"}
"$JAVA_RUNTIME/bin/javac" -d "$OUT/java" "$ROOT/chromeos/app/src/main/java/land/nithi/life/LifeEngine.java" "$ROOT/chromeos/app/src/main/java/land/nithi/life/Patterns.java" "$ROOT/tests/EngineJavaTest.java" "$ROOT/tests/PopulationJavaTest.java"
"$JAVA_RUNTIME/bin/java" -cp "$OUT/java" EngineJavaTest
"$JAVA_RUNTIME/bin/java" -cp "$OUT/java" PopulationJavaTest

python3 "$ROOT/tests/v2-compatibility.py"
