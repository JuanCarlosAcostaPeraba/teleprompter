#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release "$@"
binary_dir="$(swift build -c release --show-bin-path "$@")"
app="dist/Teleprompter.app"
icon_dir="$(mktemp -d)"
trap 'rm -rf "$icon_dir"' EXIT
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$icon_dir/Teleprompter.iconset"
swift scripts/make-icon.swift "$icon_dir/Teleprompter.iconset"
iconutil --convert icns --output "$app/Contents/Resources/Teleprompter.icns" "$icon_dir/Teleprompter.iconset"
install -m 755 "$binary_dir/Teleprompter" "$app/Contents/MacOS/Teleprompter"
cp scripts/Info.plist "$app/Contents/Info.plist"
cp -R Sources/Teleprompter/Resources/*.lproj "$app/Contents/Resources/"
codesign --force --sign "${TELEPROMPTER_SIGN_IDENTITY:--}" "$app"
printf '%s\n' "$PWD/$app"
