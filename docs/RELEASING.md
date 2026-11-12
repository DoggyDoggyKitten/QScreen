# Releases

## Current developer preview

The preview is ad hoc signed, not Developer ID signed or notarized. macOS may block the app or its screen saver. It is a development and evaluation download, not a notarized public release. No recommendation to disable Gatekeeper or other security protections is included.

Download the DMG or ZIP from the [preview release](https://github.com/DoggyDoggyKitten/QScreen/releases/tag/v0.5.3-preview.1). For private repositories, downloads are restricted to people with repository access. The source archives that GitHub adds automatically are not the app download.

The DMG provides QScreen.app and an Applications shortcut. Copy the app to Applications, eject the disk image, then open the installed app. The app's setup guide installs its embedded native screen saver into `~/Library/Screen Savers/QScreen.saver`; this is a local per-user folder outside the app bundle, not a remote destination or administrator-level installation.

If macOS blocks the preview, use a local source build or wait for a notarized release. Building from source is documented in [Development](DEVELOPMENT.md#build-and-install).

## Prepare preview artifacts

From a clean committed checkout:

```sh
bash scripts/package-release.sh --preview
```

To use a freshly built and verified app instead of rebuilding:

```sh
bash scripts/package-release.sh --preview --no-build
```

Outputs go to `build/releases/`: a DMG, a ZIP, a JSON manifest containing the source commit and signing status, and SHA-256 checksums. The app, its embedded screen saver and the standalone development screen saver include the MIT license and third-party notices. The package does not contain credentials or provisioning secrets.

When creating a GitHub release, target the manifest's exact source commit, mark the release as a prerelease, attach the four generated files, and retain the signing warning. Do not change repository visibility as part of packaging or release creation.

## Notarized distribution

The current build uses ad hoc signing. Before publishing a normal consumer release:

1. Enroll in the Apple Developer Program and configure a Developer ID Application certificate and its private key in Keychain. Keep credentials out of Git and chat.
2. Update signing to use Developer ID, secure timestamps and the hardened runtime, signing nested screen saver code before the outer app.
3. Submit all distributed executable code to Apple's notary service using `notarytool`; check the acceptance result and logs.
4. Staple tickets to supported containers, verify Gatekeeper assessment, and test the app and native screen saver after an actual browser download on another Mac.
5. Publish a stable release only after those checks pass. The preview packaging script intentionally does not offer a notarized-release mode.

Notarization is Apple's automated distribution check, not Mac App Store review. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
