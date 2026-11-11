#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Shared/QSState.m Tests/StateTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/state-tests
build/tests/state-tests
bash scripts/build-saver.sh
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Tests/RenderTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/render-tests
build/tests/render-tests
