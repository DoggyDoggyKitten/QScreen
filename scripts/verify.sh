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
for bundle in build/QScreen.app build/QScreen.saver build/QScreen.app/Contents/Resources/QScreen.saver; do
  cmp LICENSE "$bundle/Contents/Resources/LICENSE"
  cmp docs/THIRD_PARTY_NOTICES.md "$bundle/Contents/Resources/THIRD_PARTY_NOTICES.md"
done
printf '%s\n' 'Verified app and saver signatures, arm64 and x86_64 architectures, licenses and notices.'
