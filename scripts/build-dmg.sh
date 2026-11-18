#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
app="dist/Teleprompter.app"
output="dist/Teleprompter.dmg"
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --notarize ) ]]; then
    printf 'Usage: %s [--notarize]\n' "$0" >&2
    exit 2
fi

notarize="${1:-}"
if [[ "$notarize" == --notarize ]]; then
    identity="${TELEPROMPTER_SIGN_IDENTITY:-}"
    profile="${TELEPROMPTER_NOTARY_PROFILE:-}"
    if [[ "$identity" != "Developer ID Application: "* || -z "$profile" ]]; then
        printf '%s\n' 'Set TELEPROMPTER_SIGN_IDENTITY to the full Developer ID Application identity and TELEPROMPTER_NOTARY_PROFILE to a notarytool Keychain profile.' >&2
        exit 2
    fi
    if ! security find-identity -v -p codesigning | rg -F -- "\"$identity\"" >/dev/null; then
        printf '%s\n' 'The Developer ID Application identity and its private key are not available in the Keychain.' >&2
        exit 2
    fi
fi

codesign --verify --strict "$app"

staging="$(mktemp -d dist/.dmg-build.XXXXXX)"
trap 'rm -rf "$staging"' EXIT

if [[ "$notarize" == --notarize ]]; then
    ditto "$app" "$staging/Teleprompter.app"
    app="$staging/Teleprompter.app"
    codesign --force --sign "$identity" --options runtime --timestamp \
        --entitlements scripts/distribution.entitlements "$app"
    codesign --verify --strict "$app"
fi

image="$PWD/$staging/Teleprompter.dmg"
uvx --from 'dmgbuild==2.0.0' dmgbuild -s scripts/dmg-layout.py \
    -D "app=$PWD/$app" -D "assets=$PWD/scripts/assets" Teleprompter "$image"

if [[ "$notarize" == --notarize ]]; then
    codesign --sign "$identity" --timestamp "$image"
    notarization="$staging/notarization.plist"
    xcrun notarytool submit "$image" --keychain-profile "$profile" --wait --output-format plist > "$notarization"
    if [[ "$(/usr/libexec/PlistBuddy -c 'Print status' "$notarization")" != Accepted ]]; then
        cat "$notarization" >&2
        exit 1
    fi
    xcrun stapler staple "$image"
    xcrun stapler validate "$image"
    codesign --verify --strict "$image"
fi

hdiutil verify "$image"
mv -f "$image" "$output"
printf '%s\n' "$PWD/$output"
