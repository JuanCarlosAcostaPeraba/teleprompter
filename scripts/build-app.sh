#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release "$@"
binary_dir="$(swift build -c release --show-bin-path "$@")"
app="dist/Teleprompter.app"
mkdir -p "$app/Contents/MacOS"
install -m 755 "$binary_dir/Teleprompter" "$app/Contents/MacOS/Teleprompter"
cp scripts/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
printf '%s\n' "$PWD/$app"
