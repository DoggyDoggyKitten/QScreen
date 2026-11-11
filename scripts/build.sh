#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-saver.sh
output="build/QScreen.app/Contents"
mkdir -p "$output/MacOS" "$output/Resources" build/obj build/module-cache
for arch in arm64 x86_64; do
  mkdir -p "build/obj/$arch"
  xcrun clang -fobjc-arc -Wall -Wextra -Werror -target "$arch-apple-macos13.0" \
    -c -I Shared Shared/QSState.m -o "build/obj/$arch/QSState.o"
  xcrun clang -fobjc-arc -Wall -Wextra -Werror -target "$arch-apple-macos13.0" \
    -c -I Shared Shared/QSSceneView.m -o "build/obj/$arch/QSSceneView.o"
  xcrun swiftc -swift-version 5 -warnings-as-errors -O -parse-as-library -target "$arch-apple-macosx13.0" \
    -module-cache-path build/module-cache -I Shared -import-objc-header Shared/QScreen-Bridging.h \
    App/Entry.swift App/QScreenModel.swift App/Views.swift App/AppDelegate.swift \
    "build/obj/$arch/QSState.o" "build/obj/$arch/QSSceneView.o" \
    -framework AppKit -framework SwiftUI -framework ScreenSaver -framework QuartzCore \
    -framework Carbon -framework ApplicationServices -o "build/obj/$arch/QScreen"
done
lipo -create build/obj/arm64/QScreen build/obj/x86_64/QScreen -output "$output/MacOS/QScreen"
cp App/Info.plist "$output/Info.plist"
if [ ! -f App/Resources/AppIcon.icns ]; then bash scripts/make-icon.sh; fi
cp App/Resources/AppIcon.icns "$output/Resources/AppIcon.icns"
rm -rf "$output/Resources/QScreen.saver"
cp -R build/QScreen.saver "$output/Resources/QScreen.saver"
codesign --force --sign - --timestamp=none build/QScreen.app
printf '%s\n' "Built build/QScreen.app"
