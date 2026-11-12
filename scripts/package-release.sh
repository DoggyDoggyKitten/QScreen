#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

preview=false
rebuild=true
for argument in "$@"; do
  case "$argument" in
    --preview) preview=true ;;
    --no-build) rebuild=false ;;
    *) printf 'Unknown argument: %s\n' "$argument" >&2; exit 2 ;;
  esac
done
if [ "$preview" != true ]; then
  printf '%s\n' 'Only explicitly labeled developer previews are supported. Use --preview; see docs/RELEASING.md for notarized distribution.' >&2
  exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
  printf '%s\n' 'Commit source changes before packaging a release so the manifest identifies the exact source.' >&2
  exit 1
fi
if [ "$rebuild" = true ]; then bash scripts/build.sh; fi
bash scripts/verify.sh

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '%s\n' 'Expected a numeric major.minor.patch version.' >&2
  exit 1
fi
for bundle in build/QScreen.app build/QScreen.saver; do
  actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")
  if [ "$actual" != "$version" ]; then printf 'Stale bundle: %s\n' "$bundle" >&2; exit 1; fi
done
signature=$(codesign -dv build/QScreen.app 2>&1)
case "$signature" in
  *Signature=adhoc*) ;;
  *) printf '%s\n' 'This script is for ad hoc developer previews; use a verified notarization workflow for Developer ID builds.' >&2; exit 1 ;;
esac

name="QScreen-$version-preview.1"
artifacts="build/releases"
stage="build/release-stage/$name"
mkdir -p "$artifacts"
rm -rf "$stage"
mkdir -p "$stage"
ditto build/QScreen.app "$stage/QScreen.app"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE"
cp docs/THIRD_PARTY_NOTICES.md "$stage/THIRD_PARTY_NOTICES.md"
cat > "$stage/START-HERE.txt" <<EOF
QScreen $version - Developer Preview

This preview is ad hoc signed and has NOT been notarized by Apple.
macOS may block the app or its screen saver. This is a development and
evaluation build, not a notarized public release.

Requires macOS 13 or later; supports Apple Silicon and Intel Macs.

1. Copy QScreen.app to Applications.
2. If using the DMG, eject it before opening the installed app.
3. Open QScreen and follow its setup guide.
4. Click the QScreen menu bar icon, adjust the minutes, then choose a reason.
   Control-Option-Q also opens the menu. Full-screen preview does not lock.

If macOS blocks this preview, build from source or wait for a notarized
release. Do not disable system security protections.

Source and local build instructions:
https://github.com/DoggyDoggyKitten/QScreen

QScreen is MIT licensed. See LICENSE and THIRD_PARTY_NOTICES.md.
EOF
ditto -c -k --sequesterRsrc --keepParent "$stage" "$artifacts/$name.zip"
hdiutil create -ov -fs HFS+ -format UDZO -volname 'QScreen Preview' \
  -srcfolder "$stage" "$artifacts/$name.dmg"

python3 - "$artifacts" "$name" "$version" <<'PY'
import hashlib, json, pathlib, subprocess, sys
folder, name, version = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
files = []
for suffix in ['dmg', 'zip']:
    path = folder / f'{name}.{suffix}'
    files.append({'name': path.name, 'size': path.stat().st_size,
                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
manifest = {'version': version, 'tag': f'v{version}-preview.1',
            'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'license': 'MIT', 'prerelease': True, 'developerIdSigned': False,
            'notarized': False, 'architectures': ['arm64', 'x86_64'], 'files': files}
manifest_path = folder / f'{name}.json'
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
paths = [folder / item['name'] for item in files] + [manifest_path]
(folder / 'SHA256SUMS.txt').write_text(''.join(
    f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in paths))
print(f'Packaged developer preview: {folder / name}')
PY
