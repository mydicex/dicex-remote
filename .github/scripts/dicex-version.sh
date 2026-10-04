#!/usr/bin/env bash
# DiceX: applies DiceX Remote's version to a CI build (dicex-windows.yml, dicex-macos.yml,
# dicex-android.yml).
#
# The version is <RustDesk core>-<DiceX version>.<build>, e.g. 1.5.0-1.0.11, and its one source is
# flutter/lib/dicex/version.dart (see the comment there). This script
#   - fails when that file's core version is not Cargo.toml's (they must move together),
#   - writes flutter/pubspec.yaml's version as <full>+<1000 + build>: Android versionName and
#     versionCode, the macOS bundle versions, the Windows runner's file version,
#   - writes the Windows portable exe's ProductVersion and FileVersion strings,
#   - exports DICEX_VERSION for file names.
# 1000 + build keeps Android's versionCode above the 68 that builds 1-10 carried (pubspec 1.5.0+68).
set -euo pipefail

# Windows runners check out with CRLF.
read_text() { tr -d '\r' < "$1"; }

core=$(read_text Cargo.toml | sed -n 's/^version = "\(.*\)"$/\1/p' | head -n 1)
dart_core=$(read_text flutter/lib/dicex/version.dart | sed -n "s/^const String kDiceXCoreVersion = '\(.*\)';$/\1/p")
dx=$(read_text flutter/lib/dicex/version.dart | sed -n "s/^const String kDiceXVersion = '\(.*\)';$/\1/p")

if [ -z "$core" ] || [ -z "$dx" ] || [ "$core" != "$dart_core" ]; then
  echo "::error::flutter/lib/dicex/version.dart (core '$dart_core', DiceX '$dx') must match Cargo.toml (core '$core')"
  exit 1
fi
build=${dx##*.}
case "$build" in
  '' | *[!0-9]*) echo "::error::the DiceX version '$dx' must end in a build number"; exit 1 ;;
esac

full="$core-$dx"
code=$((1000 + build))

perl -pi.bak -e "s/^version: .*/version: $full+$code/" flutter/pubspec.yaml
perl -pi.bak -e "s/^#ProductVersion = \"\"\r?\$/ProductVersion = \"$full\"\nFileVersion = \"$full\"/" libs/portable/Cargo.toml
rm -f flutter/pubspec.yaml.bak libs/portable/Cargo.toml.bak

grep -q "^version: $full+$code" flutter/pubspec.yaml || { echo "::error::could not set the version in pubspec.yaml"; exit 1; }
grep -q "^ProductVersion = \"$full\"" libs/portable/Cargo.toml || { echo "::error::could not set the version in libs/portable/Cargo.toml"; exit 1; }

echo "DICEX_VERSION=$full" >> "$GITHUB_ENV"
echo "DiceX Remote $full (build $build; Android versionCode $code before the per-ABI offset)"
