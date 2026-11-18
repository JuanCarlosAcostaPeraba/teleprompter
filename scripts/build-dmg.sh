#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
app="dist/Teleprompter.app"
output="dist/Teleprompter-macOS.dmg"
codesign --verify --strict "$app"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/volume"
ditto "$app" "$staging/volume/Teleprompter.app"
ln -s /Applications "$staging/volume/Applications"

hdiutil create -volname Teleprompter -srcfolder "$staging/volume" -fs HFS+ \
    -format UDZO -ov "$output"
hdiutil verify "$output"
printf '%s\n' "$PWD/$output"
