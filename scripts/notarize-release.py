#!/usr/bin/env python3
"""Build a Developer ID release; resume notarization using local submission journals."""

import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parent.parent


def run(*args, capture=False):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True,
                            text=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else hashlib.sha256(source.read()).hexdigest()


def verify_bundle(path, team, identifier):
    requirement = (f'anchor apple generic and identifier "{identifier}" and '
                   f'certificate leaf[subject.OU] = "{team}" and '
                   'certificate leaf[field.1.2.840.113635.100.6.1.13] exists')
    run('codesign', '--verify', '--strict', '--all-architectures', '-R', '=' + requirement, path)
    for arch in ('arm64', 'x86_64'):
        result = subprocess.run(['codesign', '-d', '--verbose=4', '--arch', arch, str(path)],
                                capture_output=True, text=True, check=True)
        details = result.stderr
        if f'TeamIdentifier={team}' not in details or 'runtime' not in details or 'Timestamp=' not in details:
            raise RuntimeError(f'Missing Developer ID team, hardened runtime, or secure timestamp: {path} ({arch})')
        entitlements = run('codesign', '-d', '--arch', arch, '--entitlements', '-', path, capture=True)
        if entitlements.strip() and plistlib.loads(entitlements.encode()):
            raise RuntimeError(f'Unexpected entitlements in {path} ({arch})')


def notarize(payload, phase, folder, options):
    journal = folder / f'{phase}.submission.json'
    checksum = digest(payload)
    auth = ('--keychain-profile', options.profile, '--keychain', options.keychain)
    if journal.exists():
        record = json.loads(journal.read_text())
        if record['sha256'] != checksum:
            raise RuntimeError(f'{phase}: payload changed after submission; do not reuse this journal')
    else:
        response = json.loads(run('xcrun', 'notarytool', 'submit', payload, *auth,
                                  '--output-format', 'json', capture=True))
        record = {'id': response['id'], 'sha256': checksum, 'file': payload.name}
        write_json(journal, record)
        print(f'{phase}: submitted {record["id"]}', flush=True)
    deadline = time.monotonic() + options.timeout
    previous = None
    while True:
        response = json.loads(run('xcrun', 'notarytool', 'info', record['id'], *auth,
                                  '--output-format', 'json', capture=True))
        status = response['status']
        if status != previous:
            print(f'{phase}: {status} ({record["id"]})', flush=True)
            previous = status
        if status != 'In Progress':
            break
        if time.monotonic() >= deadline:
            print('Apple is still processing. Rerun the same command to resume without uploading again.', flush=True)
            raise SystemExit(75)
        time.sleep(30)
    log = folder / f'{phase}.notary-log.json'
    run('xcrun', 'notarytool', 'log', record['id'], *auth, log)
    report = json.loads(log.read_text())
    if status != 'Accepted' or report['status'] != 'Accepted':
        raise RuntimeError(f'{phase}: notarization failed; inspect {log}')
    for issue in report.get('issues') or []:
        print(f'{phase}: {issue["severity"]}: {issue["message"]} ({issue.get("path", "")})', flush=True)
        if issue['severity'] == 'error':
            raise RuntimeError(f'{phase}: notarization log contains an error')
    return record['id']


def sign(path, options):
    run('codesign', '--force', '--sign', options.identity, '--keychain', options.keychain,
        '--timestamp', '--options', 'runtime', path)


def staple(path):
    run('xcrun', 'stapler', 'staple', path)
    run('xcrun', 'stapler', 'validate', path)


def clean_source(commit=None):
    if run('git', 'status', '--porcelain', capture=True).strip():
        raise RuntimeError('Commit source changes before preparing a release')
    current = run('git', 'rev-parse', 'HEAD', capture=True).strip()
    if commit is not None and current != commit:
        raise RuntimeError('Source commit changed during packaging')
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identity', required=True, help='SHA-1 identity from security find-identity -v -p codesigning')
    parser.add_argument('--team-id', required=True)
    parser.add_argument('--profile', default='QScreen', help='Existing notarytool keychain profile (never a password)')
    parser.add_argument('--keychain', default=str(Path.home() / 'Library/Keychains/login.keychain-db'))
    parser.add_argument('--timeout', type=int, default=900, help='Maximum seconds to wait per submission; resumable')
    options = parser.parse_args()
    if not re.fullmatch(r'[A-Fa-f0-9]{40}', options.identity) or not re.fullmatch(r'[A-Z0-9]{10}', options.team_id):
        parser.error('Expected a 40-character signing identity hash and a 10-character Team ID')
    if options.timeout < 1:
        parser.error('--timeout must be positive')
    commit = clean_source()
    version = plistlib.loads((ROOT / 'App/Info.plist').read_bytes())['CFBundleShortVersionString']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise RuntimeError('Expected a numeric major.minor.patch version')
    if plistlib.loads((ROOT / 'ScreenSaver/Info.plist').read_bytes())['CFBundleShortVersionString'] != version:
        raise RuntimeError('App and screen saver versions differ')
    folder = ROOT / 'build/notarization' / version
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / 'workflow.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        config = {'version': version, 'sourceCommit': commit, 'identity': options.identity.upper(), 'teamId': options.team_id}
        config_file = folder / 'source.json'
        if config_file.exists() and json.loads(config_file.read_text()) != config:
            raise RuntimeError(f'{folder}: existing workflow belongs to different source or identity; preserve its logs and use a new version')
        identities = run('security', 'find-identity', '-v', '-p', 'codesigning', options.keychain, capture=True)
        if not any(options.identity.upper() in line and 'Developer ID Application:' in line for line in identities.splitlines()):
            raise RuntimeError('Requested Developer ID Application identity is not valid in the selected keychain')
        # Validate access without ever retrieving the stored credential.
        run('xcrun', 'notarytool', 'history', '--keychain-profile', options.profile,
            '--keychain', options.keychain, '--output-format', 'json', capture=True)
        write_json(config_file, config)
        app, saver = folder / 'QScreen.app', folder / 'QScreen.saver'
        if not (folder / 'prepared.json').exists():
            run('bash', 'scripts/build.sh')
            run('bash', 'scripts/verify.sh')
            for source, destination in ((ROOT / 'build/QScreen.app', app), (ROOT / 'build/QScreen.saver', saver)):
                if destination.exists():
                    shutil.rmtree(destination)
                run('ditto', source, destination)
            sign(saver, options)
            verify_bundle(saver, options.team_id, 'com.qscreen.saver')
            write_json(folder / 'prepared.json', config)
        if not (folder / 'saver.zip').exists():
            run('ditto', '-c', '-k', '--keepParent', saver, folder / 'saver.zip')
        saver_id = notarize(folder / 'saver.zip', 'saver', folder, options)
        if not (folder / 'app-signed.json').exists():
            staple(saver)
            embedded = app / 'Contents/Resources/QScreen.saver'
            shutil.rmtree(embedded)
            run('ditto', saver, embedded)
            sign(app, options)
            verify_bundle(app, options.team_id, 'com.qscreen.app')
            verify_bundle(embedded, options.team_id, 'com.qscreen.saver')
            run('codesign', '--verify', '--deep', '--strict', app)
            write_json(folder / 'app-signed.json', config)
        if not (folder / 'app.zip').exists():
            run('ditto', '-c', '-k', '--keepParent', app, folder / 'app.zip')
        app_id = notarize(folder / 'app.zip', 'app', folder, options)
        name = f'QScreen-{version}'
        artifacts = folder / 'release'
        artifacts.mkdir(exist_ok=True)
        dmg = artifacts / f'{name}.dmg'
        stage = folder / 'stage'
        if not dmg.exists():
            staple(app)
            run('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
            if stage.exists():
                shutil.rmtree(stage)
            stage.mkdir()
            run('ditto', app, stage / 'QScreen.app')
            (stage / 'Applications').symlink_to('/Applications')
            shutil.copy2(ROOT / 'LICENSE', stage / 'LICENSE')
            shutil.copy2(ROOT / 'docs/THIRD_PARTY_NOTICES.md', stage / 'THIRD_PARTY_NOTICES.md')
            (stage / 'START-HERE.txt').write_text(
                f'QScreen {version}\n\n'
                'Requires macOS 13 or later; Apple Silicon and Intel.\n\n'
                '1. Drag QScreen.app to Applications.\n'
                '2. Eject this disk image, open QScreen, and follow setup.\n'
                '3. Click the QScreen menu bar icon and choose a reason to lock.\n\n'
                'https://github.com/DoggyDoggyKitten/QScreen\n'
                'MIT licensed; see LICENSE and THIRD_PARTY_NOTICES.md.\n')
            pending_dmg = folder / 'unsigned.dmg'
            run('hdiutil', 'create', '-ov', '-fs', 'HFS+', '-format', 'UDZO', '-volname', 'QScreen',
                '-srcfolder', stage, pending_dmg)
            run('codesign', '--force', '--sign', options.identity, '--keychain', options.keychain,
                '--timestamp', pending_dmg)
            pending_dmg.replace(dmg)
        dmg_id = notarize(dmg, 'dmg', folder, options)
        # Stapling changes the disk image digest, so retain the submitted copy for resumability.
        final_dmg = artifacts / f'{name}-notarized.dmg'
        if not final_dmg.exists():
            pending_final = folder / 'stapled.dmg'
            shutil.copy2(dmg, pending_final)
            staple(pending_final)
            run('codesign', '--verify', '--strict', pending_final)
            run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=2', pending_final)
            run('hdiutil', 'verify', pending_final)
            pending_final.replace(final_dmg)
        for bundle, identifier in ((app, 'com.qscreen.app'), (saver, 'com.qscreen.saver'),
                                   (app / 'Contents/Resources/QScreen.saver', 'com.qscreen.saver')):
            verify_bundle(bundle, options.team_id, identifier)
            run('xcrun', 'stapler', 'validate', bundle)
        run('xcrun', 'stapler', 'validate', final_dmg)
        run('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
        clean_source(commit)
        files = [{'name': final_dmg.name, 'size': final_dmg.stat().st_size, 'sha256': digest(final_dmg)}]
        manifest = {**config, 'developerIdSigned': True, 'notarized': True,
                    'license': 'MIT', 'architectures': ['arm64', 'x86_64'],
                    'submissions': {'saver': saver_id, 'app': app_id, 'dmg': dmg_id},
                    'files': files, 'browserDownloadTested': False}
        manifest_file = artifacts / f'{name}.json'
        write_json(manifest_file, manifest)
        (artifacts / 'SHA256SUMS.txt').write_text(
            f'{digest(final_dmg)}  {final_dmg.name}\n{digest(manifest_file)}  {manifest_file.name}\n')
        print(f'Notarized release candidate: {final_dmg}\nTest a real browser download on another Mac before publishing a stable release.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(error.returncode or 1)
    except (RuntimeError, BlockingIOError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
