# Teleprompter

A native macOS teleprompter that follows your voice. The floating reader stays near the camera and keeps the active line at a fixed height as you speak.

[Español](README.es.md)

## Download and install

**[Download Teleprompter for macOS (.dmg)](https://github.com/JuanCarlosAcostaPeraba/teleprompter/releases/latest/download/Teleprompter-macOS.dmg)**

Requires **macOS 14 or later**. The download supports Apple Silicon and Intel.

1. Open the disk image you downloaded.
2. Drag **Teleprompter** into **Applications**, then open it from Applications.
3. Use the Teleprompter icon in the menu bar to paste or edit a script and open the reader.

The public download uses ad hoc signing and is not notarized. If macOS blocks the download, you can build the app locally from the instructions below. When you first start listening, macOS may ask for microphone and speech recognition permissions.

## Read a script

- Choose a speech recognition language in Settings. To prepare additional languages, open **Configure Dictation Languages**, then go to **Keyboard → Dictation → Languages** in System Settings. On-device availability varies by language and Mac.
- Open the reader from a saved script or directly from the clipboard. Clipboard text does not replace the saved script. Stage directions in square brackets are skipped by voice tracking.
- The reader opens below the camera. Drag its edges to resize it, or double-click the free strip at the top to put it back in position. Settings includes a live preview.
- Click a word or use the navigation buttons to move manually. The current line stays near the top with one previous line visible. The listening button shows the current audio input. You can turn off automatic listening in Settings.
- Settings includes optional Liquid Glass styling on macOS 26 and later. The Dock icon and menu bar icon can be hidden independently. You can reopen Settings with the Raycast script in [scripts/raycast](scripts/raycast) or with the URL `teleprompter://settings`.

## Updates

Choose **Check for Updates** in Settings. The app checks the latest stable GitHub release. If a newer version is available, use **Download and Open DMG** to download and verify it without opening a browser. Quit Teleprompter, drag the new app into Applications, and replace the old version. Your script and preferences are stored separately and carry over.

## Screen sharing and privacy

The script and recognition are processed on your Mac. **Request Capture Exclusion** asks macOS to exclude the reader window. Results depend on the app and capture method. Use the sharing preview to check the result before you start.

## Build from source

Use Xcode 26 or later with its command-line tools selected.

```sh
swift test
./scripts/build-app.sh
open dist/Teleprompter.app
```

To package a universal disk image:

```sh
./scripts/build-app.sh --arch arm64 --arch x86_64
./scripts/build-dmg.sh
```

Upload `dist/Teleprompter-macOS.dmg` to a stable GitHub release tagged `vMAJOR.MINOR.PATCH`. Keep the filename unchanged so the direct download and update checker can find it. For local development, set `TELEPROMPTER_SIGN_IDENTITY` to keep using the same signing identity across builds. Changes to an ad hoc build can cause macOS to ask for permissions again.
