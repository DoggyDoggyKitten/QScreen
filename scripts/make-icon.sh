#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tools App/Resources
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Tools/MakeIcon.m Shared/QSSceneView.m Shared/QSState.m \
  -framework AppKit -framework ScreenSaver -o build/tools/make-icon
build/tools/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o App/Resources/AppIcon.icns
