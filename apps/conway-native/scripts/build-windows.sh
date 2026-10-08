#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
export DOTNET_CLI_HOME="$REPO/tmp/dotnet" NUGET_PACKAGES="$REPO/tmp/nuget" DOTNET_CLI_TELEMETRY_OPTOUT=1
mkdir -p "$REPO/dist/conway-native"
dotnet publish "$ROOT/windows/NithiLife.csproj" -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o "$REPO/dist/conway-native/windows"
dotnet run --project "$ROOT/tests/windows-assets/AssetChecks.csproj" -c Release -- "$ROOT/windows/bin/Release/net10.0-windows/win-x64/Conway's Game of Life Lab.dll" "$ROOT/windows/AppIcon.ico" "$ROOT/shared/tour.json"
mv "$REPO/dist/conway-native/windows/Conway's Game of Life Lab.exe" "$REPO/dist/conway-native/windows/Conway's Game of Life Lab-3.2-testing.exe"
cp "$REPO/dist/conway-native/windows/Conway's Game of Life Lab-3.2-testing.exe" "$REPO/dist/conway-native/Conways-Game-of-Life-Lab-3.2-testing.exe"
