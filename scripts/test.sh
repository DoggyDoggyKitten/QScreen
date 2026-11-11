#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Shared/QSState.m Tests/StateTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/state-tests
build/tests/state-tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  '-DQS_PREFERENCES_DOMAIN=@"com.qscreen.saver.tests"' \
  Shared/QSState.m Tests/StoreProbe.m -framework AppKit -framework ScreenSaver \
  -o build/tests/store-probe
trap 'build/tests/store-probe clear' EXIT
build/tests/store-probe write
build/tests/store-probe read
build/tests/store-probe clear
build/tests/store-probe empty
bash scripts/build-saver.sh
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Tests/RenderTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/render-tests
build/tests/render-tests
