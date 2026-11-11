#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
codesign --verify --deep --strict build/QScreen.app
codesign --verify --strict build/QScreen.saver
for binary in build/QScreen.app/Contents/MacOS/QScreen build/QScreen.saver/Contents/MacOS/QScreen; do
  architectures=" $(xcrun lipo -archs "$binary") "
  for architecture in arm64 x86_64; do
    case "$architectures" in
      *" $architecture "*) ;;
      *) printf 'Missing %s architecture: %s\n' "$architecture" "$binary" >&2; exit 1 ;;
    esac
  done
done
printf '%s\n' 'Verified app and saver signatures, arm64 and x86_64 architectures.'
