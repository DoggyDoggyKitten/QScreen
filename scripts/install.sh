#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d build/QScreen.app ] || [ ! -d build/QScreen.saver ]; then
  printf '%s\n' 'Build first: bash scripts/build.sh' >&2
  exit 1
fi
install_bundle() {
  local source="$1" destination="$2" expected="$3" actual
  if [ -e "$destination" ]; then
    actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")
    if [ "$actual" != "$expected" ]; then
      printf 'Refusing to overwrite another bundle: %s\n' "$destination" >&2
      exit 1
    fi
  fi
  mkdir -p "$(dirname "$destination")"
  local stage="$destination.staging.$$" backup="$destination.backup.$$"
  ditto "$source" "$stage"
  codesign --verify --deep --strict "$stage"
  if [ -e "$destination" ]; then mv "$destination" "$backup"; fi
  if ! mv "$stage" "$destination"; then
    if [ -e "$backup" ]; then mv "$backup" "$destination"; fi
    exit 1
  fi
  if [ -e "$backup" ]; then rm -rf "$backup"; fi
}
install_bundle build/QScreen.app "$HOME/Applications/QScreen.app" com.qscreen.app
install_bundle build/QScreen.saver "$HOME/Library/Screen Savers/QScreen.saver" com.qscreen.saver
printf '%s\n' 'Installed. Open ~/Applications/QScreen.app, select QScreen as the system saver and require a password immediately after the saver starts.'

