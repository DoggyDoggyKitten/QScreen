#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != '--no-build' ]; then bash scripts/build.sh; fi
codesign --verify --deep --strict build/QScreen.app
codesign --verify --strict build/QScreen.saver
folder="build/QScreen-0.1.0"
mkdir -p "$folder"
ditto build/QScreen.app "$folder/QScreen.app"
ditto build/QScreen.saver "$folder/QScreen.saver"
cp README.md "$folder/README.md"
ditto docs "$folder/docs"
cp docs/INSTALL.txt "$folder/使用说明.txt"
ditto -c -k --sequesterRsrc --keepParent "$folder" build/QScreen-0.1.0.zip
printf '%s\n' 'Packaged build/QScreen-0.1.0.zip'
