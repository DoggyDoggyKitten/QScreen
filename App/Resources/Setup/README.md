# Setup screenshots

Captured on macOS 27.0.1 on 2026-11-11, with the system interface in English.

- `wallpaper.png`: real Wallpaper settings content area; the account sidebar is excluded.
- `screen-saver.png`: the real screen saver sheet opened by the user, with Custom and QScreen selected. No account name or personal photo is visible.
- `password.png`: real Lock Screen settings content area showing Immediately; the account sidebar is excluded.

These are static bundled images. The app does not record the user's screen or request screen recording or accessibility access. Focus outlines and zoom controls are drawn by SwiftUI over the screenshots. Keep the focus rectangles in `SetupScreenshot` aligned when replacing these images.

Apple references for settings paths:

- https://support.apple.com/guide/mac-help/mchl4b68853d/mac
- https://support.apple.com/guide/mac-help/mh11784/mac
