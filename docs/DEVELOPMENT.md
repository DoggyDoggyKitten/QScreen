# Development

## Build and install

Requires macOS 13 or later and Xcode with its command-line tools. The build includes Apple Silicon and Intel binaries and has no third-party dependencies.

```sh
git clone https://github.com/DoggyDoggyKitten/QScreen.git
cd QScreen
bash scripts/build.sh
bash scripts/install.sh
open ~/Applications/QScreen.app
```

The installer places the app in `~/Applications/QScreen.app` and the native screen saver in `~/Library/Screen Savers/QScreen.saver` without administrator access. It checks bundle identifiers before replacing an existing installation.

Follow the app's first-run guide:

1. Install the screen saver.
2. Open System Settings → Wallpaper → Screen Saver….
3. Select Custom, scroll to Other, choose QScreen, and click Done. Return to the app to confirm your selection.
4. In Lock Screen settings, require a password immediately after the screen saver begins or the display turns off.
5. Choose Finish & open menu. Adjust the return time before clicking a reason to start the screen saver and lock.

The guide uses illustrated settings references and needs no screen recording or accessibility permission. System controls may differ by macOS version. The app checks the password policy before completing setup and before each departure; it does not change that policy or select the system screen saver on your behalf.

Local builds are ad hoc signed, without Developer ID signing or notarization. Cross-machine distribution requires signing, notarization and testing on the target macOS version.

## Everyday use

Click the menu bar icon or press Control–Option–Q. Click a duration to change it, then click a reason to leave. Custom reasons support 1–480 minutes and up to 40 characters. Chinese and English settings persist across launches; custom text stays as entered.

Full-screen preview does not lock. The away action launches the native system screen saver after checking the immediate-password policy. The standard macOS Control–Command–Q shortcut may initially show the system's lock background instead.

The app must remain running to supply status to a newly launched screen saver. Unlock notifications, returning to the app, quitting, and expired status clear away metadata. These notifications are not authentication signals.

## Verify and package

```sh
bash scripts/test.sh
bash scripts/verify.sh
bash scripts/package.sh
```

The package contains the app, screen saver, README and supporting documentation.

```sh
open -n ~/Applications/QScreen.app --args --smoke-test
open -n ~/Applications/QScreen.app --args --setup-smoke-test
```

The first command checks typed custom input, language persistence, duration settings and menu behavior. The second renders all five onboarding steps in both languages, checks resuming and completion, and checks that finishing opens the menu while incomplete setup does not. They write results to `/tmp/qscreen-smoke/` and `/tmp/qscreen-setup-smoke/`, restore the preferences they exercise, and do not lock the screen.

Tests also cover countdowns, expired or invalid state, cross-process preferences and status synchronization, bilingual screen saver rendering, font fallback, native screen saver lifecycle, and strict password-policy parsing. Manual hardware and secure-lock checks are listed in [acceptance steps](ACCEPTANCE.md).

## Implementation

- `App/`: SwiftUI menu bar app, global shortcut, onboarding and preview.
- `ScreenSaver/`: native Objective-C `ScreenSaverView` module.
- `Shared/`: validated state, local preferences, cross-process status notifications and AppKit vector character animation.
- `Tests/` and `scripts/`: verification, building, installing and packaging.

The app and screen saver host can use isolated preferences domains. Validated distributed notifications bridge display status; they are never used for authentication. Diagnostics are local in `~/Library/Logs/QScreen/`; `open -g qscreen://diagnostics` refreshes the snapshot.

Time-limited IOKit assertions keep the display on for the configured period. They do not alter power-management or security settings, prevent manual sleep, or render while the computer sleeps. Closed-lid use depends on the Mac's supported external-display setup. Multiple displays, lid states and native locking need verification on the actual hardware.

The [previous Chinese technical guide](DEVELOPMENT.zh-CN.md) is retained for reference. README illustration provenance and generation prompts are in [artwork notes](reference/readme-art.md).
