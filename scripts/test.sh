#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
PYTHONDONTWRITEBYTECODE=1 python3 Tests/NotarizationTests.py
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Shared/QSState.m Tests/StateTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/state-tests
build/tests/state-tests
xcrun swiftc -swift-version 5 -warnings-as-errors -parse-as-library \
  App/ScreenLockPolicy.swift Tests/ScreenLockPolicyTests.swift -o build/tests/lock-policy-tests
build/tests/lock-policy-tests
xcrun swiftc -swift-version 5 -warnings-as-errors -parse-as-library \
  App/ScreenLockPolicy.swift App/SetupFlow.swift Tests/SetupFlowTests.swift -o build/tests/setup-flow-tests
build/tests/setup-flow-tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  '-DQS_PREFERENCES_DOMAIN=@"com.qscreen.saver.tests"' \
  Shared/QSState.m Tests/StoreProbe.m -framework AppKit -framework ScreenSaver \
  -o build/tests/store-probe
trap 'build/tests/store-probe clear' EXIT
build/tests/store-probe write
build/tests/store-probe read
build/tests/store-probe clear
build/tests/store-probe empty
for role in provider client; do
  xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
    "-DQS_PREFERENCES_DOMAIN=@\"com.qscreen.saver.tests.$role\"" \
    '-DQS_RUNTIME_CHANNEL=@"com.qscreen.bridge.tests"' \
    Shared/QSState.m Tests/BridgeProbe.m -framework AppKit -framework ScreenSaver \
    -o "build/tests/bridge-$role"
done
python3 Tests/BridgeTests.py
bash scripts/build-saver.sh --test
xcrun clang -fobjc-arc -Wall -Wextra -Werror -I Shared \
  Tests/RenderTests.m -framework AppKit -framework ScreenSaver \
  -o build/tests/render-tests
build/tests/render-tests build/previews build/tests/QScreen.saver
