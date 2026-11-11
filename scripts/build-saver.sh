#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="build/QScreen.saver"
definitions=('-DQS_PREFERENCES_DOMAIN=@"com.qscreen.saver"' '-DQS_RUNTIME_CHANNEL=@"com.qscreen.saver.runtime"')
if [ "${1:-}" = "--test" ]; then
  bundle="build/tests/QScreen.saver"
  definitions=('-DQS_PREFERENCES_DOMAIN=@"com.qscreen.saver.tests.render"' '-DQS_RUNTIME_CHANNEL=@"com.qscreen.render.tests"')
fi
output="$bundle/Contents"
mkdir -p "$output/MacOS" "$output/Resources" build/obj
xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=13.0 \
  -arch arm64 -arch x86_64 \
  -bundle -I Shared "${definitions[@]}" Shared/QSState.m Shared/QSSceneView.m ScreenSaver/QScreenSaverView.m \
  -framework AppKit -framework ScreenSaver -framework IOKit -framework QuartzCore \
  -o "$output/MacOS/QScreen"
cp ScreenSaver/Info.plist "$output/Info.plist"
codesign --force --sign - --timestamp=none "$bundle"
printf '%s\n' "Built $bundle"
