# Teleprompter

A native macOS teleprompter that follows your voice. The floating reader stays near the camera and keeps the active line at a fixed height as you speak.

[![Download DMG](https://img.shields.io/badge/Download_DMG-087C73?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest/download/Teleprompter.dmg)

[![Teleprompter highlights the active word as you speak. Download the macOS disk image.](docs/assets/teleprompter-banner.png)](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest/download/Teleprompter.dmg)

[![Latest release](https://img.shields.io/github/v/release/JuanCarlosAcostaPeraba/teleprompter?style=flat-square&label=Latest%20release&color=087C73)](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-263B50?style=flat-square&logo=apple&logoColor=white)](#download-and-install)
· [Español](README.es.md)

## Download and install

**[Download Teleprompter for macOS (.dmg)](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest/download/Teleprompter.dmg)**

Requires **macOS 14 or later**. The download supports Apple Silicon and Intel.

1. Open the disk image you downloaded.
2. Drag **Teleprompter** into **Applications**, then open it from Applications.
3. Use the Teleprompter icon in the menu bar to paste or edit a script and open the reader.

The public download uses ad hoc signing and is not notarized. If macOS blocks the first launch and you trust the download from this repository, close the alert and go to **System Settings → Privacy & Security → Open Anyway**. This authorizes this app on your Mac. You can also [build it from source](#build-from-source). [Apple's guide to opening apps](https://support.apple.com/en-us/102445)

When you first start listening, macOS may ask for microphone and speech recognition permissions.

## Read a script

- Use **App Language** in Settings to switch between English and Spanish. Teleprompter uses your macOS language preferences until you choose a language.
- Choose a speech recognition language in Settings. To prepare additional languages, open **Configure Dictation Languages**, then go to **Keyboard → Dictation → Languages** in System Settings. On-device availability varies by language and Mac.
- Open the reader from a saved script or directly from the clipboard. Clipboard text does not replace the saved script. Stage directions in square brackets are skipped by voice tracking.
- The reader opens below the camera. Drag its edges to resize it, or double-click the free strip at the top to put it back in position. Settings includes a live preview.
- Click a word or use the navigation buttons to move manually. The current line stays near the top with one previous line visible. The listening button shows the current audio input. You can turn off automatic listening in Settings.
- Settings includes optional Liquid Glass styling on macOS 26 and later. The Dock icon and menu bar icon can be hidden independently. You can reopen Settings with the Raycast script in [scripts/raycast](scripts/raycast) or with the URL `teleprompter://settings`.

## Updates

Teleprompter checks the latest stable GitHub release at startup and once a day while open. A new version appears in Settings and marks the menu bar and Dock icons when visible. You can also choose **Check for Updates** in Settings.

When an update is available, **Download** takes the place of **Check for Updates**. Click it to download the verified installer. Then quit Teleprompter and drag the new app to Applications to replace the old version.

## Screen sharing and privacy

The script and recognition are processed on your Mac. **Request Capture Exclusion** asks macOS to exclude the reader window. Results depend on the app and capture method. Use the sharing preview to check the result before you start.

## Build from source

Use Xcode 26 or later with its command-line tools selected.

```sh
swift test
./scripts/build-app.sh
open dist/Teleprompter.app
```

Install [uv](https://docs.astral.sh/uv/getting-started/installation/) to package a universal disk image with the custom Finder layout:

```sh
./scripts/build-app.sh --arch arm64 --arch x86_64
./scripts/build-dmg.sh
```

The build produces `dist/Teleprompter.dmg` for local testing. See [Releasing Teleprompter](docs/releasing.md) for signing, notarization, and compatibility with older updaters. For local development, set `TELEPROMPTER_SIGN_IDENTITY` to keep using the same signing identity across builds. Changes to an ad hoc build can cause macOS to ask for permissions again.
