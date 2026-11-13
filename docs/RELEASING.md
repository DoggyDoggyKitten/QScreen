# Releases

## Current notarized preview

[QScreen 0.5.4 release candidate](https://github.com/DoggyDoggyKitten/QScreen/releases/tag/v0.5.4-rc.1) is Developer ID signed and notarized. The native screen saver, app and DMG each received Accepted responses with no reported issues. Their tickets were stapled and validated. Gatekeeper assessment passed on the build Mac, including the app read from the final DMG. The public download's SHA-256 matched the packaged artifact and its ticket validated.

Only the notarized DMG is uploaded as an app download. This remains a prerelease while browser-download installation, setup and authenticated lock are verified on another Mac. Automated build, state, lock-policy, setup, bridge, rendering and notarization failure-path checks passed. These checks do not establish browser-download installation behavior on another machine.

## Earlier developer preview

Version 0.5.3-preview.1 is ad hoc signed, not Developer ID signed or notarized. macOS may block the app or its screen saver. Prefer the current notarized preview above. No recommendation to disable Gatekeeper or other security protections is included.

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

Enroll in the Apple Developer Program and install a Developer ID Application certificate with its matching private key in the login keychain. Keep credentials out of Git and chat. If importing the certificate fails with error -25294, explicitly target the login keychain; also install Apple's official Developer ID G2 intermediate certificate if needed. Do not override certificate trust settings.

Create an app-specific password in your Apple Account. Save it interactively in your own terminal (omit `--password` so it is not recorded in shell history):

```sh
xcrun notarytool store-credentials QScreen --apple-id YOUR_APPLE_ACCOUNT --team-id YOUR_TEAM_ID --keychain ~/Library/Keychains/login.keychain-db
```

From a clean committed checkout, find the Developer ID Application identity with `security find-identity -v -p codesigning`, then run:

```sh
python3 scripts/notarize-release.py --identity YOUR_CERTIFICATE_SHA1 --team-id YOUR_TEAM_ID
```

The workflow builds both architectures, signs the screen saver with Developer ID, hardened runtime and a secure timestamp, notarizes and staples it, embeds it in the app, then signs/notarizes/staples the app. Finally it creates, signs, notarizes and staples a DMG. It validates both architectures' signatures, team IDs and tickets and runs Gatekeeper assessments. No extra entitlements or custom trust settings are added.

Submission IDs, Apple logs and intermediate artifacts stay in ignored `build/notarization/VERSION/`. Rerun the same command after a timeout or network failure to resume the existing submissions. The workflow refuses to resume against changed source or a different identity. Preserve those records and increment the version for a new build. An Accepted response and a successful ticket/signature assessment are required before a final manifest can claim notarization.

The final `*-notarized.dmg`, JSON manifest and checksums are in `build/notarization/VERSION/release/`. Signed intermediate images are kept separately for resumability. The script does not publish or replace a GitHub release. Test app launch, setup, saver installation/loading and authenticated lock after an actual browser download on another Mac before publishing a stable release. The manifest explicitly records that this manual test is still outstanding.

Notarization is Apple's automated distribution check, not Mac App Store review. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
