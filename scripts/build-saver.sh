#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="build/QScreen.saver/Contents"
mkdir -p "$output/MacOS" "$output/Resources" build/obj
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=13.0 \
  -arch arm64 -arch x86_64 \
  -bundle -I Shared Shared/QSState.m Shared/QSSceneView.m ScreenSaver/QScreenSaverView.m \
  -framework AppKit -framework ScreenSaver -framework IOKit -framework QuartzCore \
  -o "$output/MacOS/QScreen"
cp ScreenSaver/Info.plist "$output/Info.plist"
codesign --force --sign - --timestamp=none build/QScreen.saver
printf '%s\n' "Built build/QScreen.saver"
