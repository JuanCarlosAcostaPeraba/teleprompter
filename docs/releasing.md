# Releasing Teleprompter

Install a [Developer ID Application certificate](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) with its private key in your Keychain and [store notarization credentials](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) in a Keychain profile. Keep credentials outside the repository.

Set the release version and increment the build number in `scripts/Info.plist`. Build the universal app, then sign and notarize the disk image.

```sh
swift test
./scripts/build-app.sh --arch arm64 --arch x86_64
TELEPROMPTER_SIGN_IDENTITY='Developer ID Application: NAME (TEAMID)' \
  TELEPROMPTER_NOTARY_PROFILE='teleprompter-notary' \
  ./scripts/build-dmg.sh --notarize
xcrun stapler validate dist/Teleprompter.dmg
```

The packaging command signs a copy of the app with Hardened Runtime and the audio input entitlement. It signs the DMG, submits it to Apple and attaches the notarization ticket to the DMG. [Apple's distribution guide](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

Upload `Teleprompter.dmg` to the stable GitHub release tagged `vMAJOR.MINOR.PATCH`. Upload a byte-for-byte copy named `Teleprompter-macOS.dmg` as well. Versions 1.7.0 and 1.7.1 require that exact asset name and its matching download URL. Keep the compatibility asset available on the latest release for as long as those versions have a supported upgrade path.

The two READMEs link to `releases/latest/download/Teleprompter.dmg`. Update their signing and notarization notice when the public download starts using Developer ID and notarization.

Test the update from the official 1.7.0 with a test script and non-default settings. Download from Ajustes, open the image, quit the old app, and copy the new bundle over it in Applications. Open the installed app with Gatekeeper enabled. Check the version, the saved script and preferences, and microphone access. Keep a copy of the test preferences before replacing the app.
