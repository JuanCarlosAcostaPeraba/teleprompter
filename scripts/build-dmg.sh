#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
app="dist/Teleprompter.app"
output="dist/Teleprompter-macOS.dmg"
codesign --verify --strict "$app"

staging="$(mktemp -d dist/.dmg-build.XXXXXX)"
trap 'rm -rf "$staging"' EXIT

image="$PWD/$staging/Teleprompter-macOS.dmg"
uvx --from 'dmgbuild==2.0.0' dmgbuild -s scripts/dmg-layout.py \
    -D "app=$PWD/$app" -D "assets=$PWD/scripts/assets" Teleprompter "$image"
hdiutil verify "$image"
mv -f "$image" "$output"
printf '%s\n' "$PWD/$output"
