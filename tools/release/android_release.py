#!/usr/bin/env python3
"""Local candidate build and verification. Never uploads or changes stable manifests."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APP_ID = 'com.flandresy'
ABIS = {'arm64-v8a', 'x86_64'}
RELEASES = 'https://github.com/amamiyakazuki/FlandreSY/releases'
VERSION = re.compile(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\Z')
DIGEST = re.compile(r'[0-9a-fA-F]{64}\Z')


class ValidationError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def run(args, capture=True):
    completed = subprocess.run([str(x) for x in args], text=True,
                               stdout=subprocess.PIPE if capture else None,
                               stderr=subprocess.PIPE if capture else None)
    # Do not echo command output on failure: signing/tool errors can contain local secrets.
    require(completed.returncode == 0, f'{Path(args[0]).name} failed; candidate not verified.')
    return completed.stdout or ''


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def version_tuple(value):
    require(isinstance(value, str) and VERSION.fullmatch(value), 'Invalid stable version.')
    return tuple(int(v) for v in value.split('.'))


def positive_code(value):
    return type(value) is int and 0 < value <= 2100000000


def candidate_version(root):
    values = re.findall(r'^version:\s*(\S+)\s*$', (root / 'pubspec.yaml').read_text(), re.M)
    require(len(values) == 1 and '+' in values[0], 'pubspec requires version x.y.z+build.')
    name, code = values[0].split('+', 1)
    version_tuple(name)
    require(code.isdecimal() and positive_code(int(code)), 'Invalid candidate versionCode.')
    return name, int(code)


def stable_manifest(root):
    canonical = json.loads((root / 'assets/public/version.json').read_text())
    copy = json.loads((root / 'public/version.json').read_text())
    require(isinstance(canonical, dict) and isinstance(copy, dict), 'Stable manifest must be an object.')
    require(canonical == copy, 'Stable manifest copies differ; synchronize reviewed published metadata.')
    version_tuple(canonical.get('version'))
    require(isinstance(canonical.get('release_date'), str) and
            isinstance(canonical.get('changelog'), list) and
            all(isinstance(v, str) for v in canonical['changelog']), 'Invalid stable manifest fields.')
    expected = f"{RELEASES}/download/v{canonical['version']}/app-release.apk"
    require(isinstance(canonical.get('downloads'), dict) and canonical['downloads'].get('github') == expected, 'Invalid stable download URL.')
    if 'schemaVersion' in canonical or 'platforms' in canonical:
        require(type(canonical.get('schemaVersion')) is int and isinstance(canonical.get('platforms'), dict),
                'Invalid stable platform schema.')
        android = canonical['platforms'].get('android', {})
        require(isinstance(android, dict), 'Invalid stable Android metadata.')
        require(canonical.get('schemaVersion') == 2 and android.get('status') == 'available' and
                android.get('version') == canonical['version'] and
                positive_code(android.get('buildNumber')) and android.get('downloadUrl') == expected and
                canonical.get('platforms', {}).get('ios') == {'status': 'unavailable'},
                'Invalid stable platform metadata.')
    return canonical


def tool(name):
    executable = shutil.which(name)
    if executable:
        return executable
    sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
    if sdk:
        candidates = list((Path(sdk) / 'build-tools').glob(f'*/{name}'))
        candidates = [p for p in candidates if re.fullmatch(r'\d+\.\d+\.\d+', p.parent.name)]
        candidates.sort(key=lambda p: tuple(map(int, p.parent.name.split('.'))), reverse=True)
        if candidates:
            return str(candidates[0])
    raise ValidationError(f'Required tool {name} not found; no checks skipped.')


def apk_metadata(badging, certificates):
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging, re.M)
    architecture = re.search(r"^native-code: (.+)$", badging, re.M)
    certs = re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]{64})$', certificates, re.M)
    require(package and architecture and len(certs) == 1, 'Incomplete APK metadata or unsupported signer set.')
    return {'applicationId': package[1], 'versionCode': int(package[2]), 'versionName': package[3],
            'debuggable': bool(re.search(r'^application-debuggable(?:\s|$)', badging, re.M)),
            'abis': sorted(re.findall(r"'([^']+)'", architecture[1])),
            'certificateSha256': certs[0].lower()}


def inspect_apk(path, tools):
    return apk_metadata(run([tools['aapt'], 'dump', 'badging', path]),
                        run([tools['apksigner'], 'verify', '--print-certs', path]))


def validate_baseline(data, root, inspector):
    require(isinstance(data, dict), 'Baseline must be an object.')
    require(data.get('schemaVersion') == 1 and isinstance(data.get('scope'), str) and data['scope'].strip(),
            'Baseline requires schemaVersion=1 and an explicitly reviewed upgrade scope.')
    assets = data.get('artifacts')
    require(isinstance(assets, list) and assets, 'Baseline requires actual historical APKs.')
    records, paths = [], set()
    for asset in assets:
        require(isinstance(asset, dict) and isinstance(asset.get('path'), str) and
                isinstance(asset.get('sha256'), str) and DIGEST.fullmatch(asset['sha256']),
                'Each historical APK needs a path and independently recorded SHA-256.')
        path = (root / asset['path']).resolve()
        require(path.is_file() and path not in paths, 'Historical APK missing or duplicated.')
        paths.add(path)
        require(sha256(path) == asset['sha256'].lower(), 'Historical APK hash mismatch.')
        record = inspector(path)
        require(record['applicationId'] == APP_ID and not record['debuggable'] and
                positive_code(record['versionCode']), 'Invalid historical application identity.')
        record = dict(record, sha256=asset['sha256'].lower())
        version_tuple(record['versionName'])
        records.append(record)
    require(len({r['certificateSha256'] for r in records}) == 1, 'Historical signing certificates disagree.')
    # These are known published variants, not an assumed all-history maximum.
    known = {(r['versionCode'], tuple(r['abis'])) for r in records if r['versionName'] == '2.1.4'}
    require({(6, tuple(sorted(ABIS))), (2006, ('arm64-v8a',)), (4006, ('x86_64',))} <= known,
            'Upgrade baseline must include all three published 2.1.4 APK variants.')
    return records


def validate_candidate(name, code, records, stable):
    version_tuple(name)
    require(positive_code(code) and code > max(r['versionCode'] for r in records),
            'Candidate versionCode must exceed every inspected historical APK.')
    require(all(version_tuple(name) >= version_tuple(r['versionName']) for r in records) and
            version_tuple(name) >= version_tuple(stable['version']), 'Candidate version name would downgrade.')
    old_build = stable.get('platforms', {}).get('android', {}).get('buildNumber')
    require(old_build is None or code > old_build, 'Candidate must exceed the published build number.')


def validate_artifact(record, name, code, certificate):
    require(record['applicationId'] == APP_ID and record['versionName'] == name and
            record['versionCode'] == code and not record['debuggable'] and
            set(record['abis']) == ABIS and record['certificateSha256'] == certificate,
            'Artifact identity/version/signature/ABI does not match the verified candidate.')


def inspect_aab(path, bundletool, java, keytool, jarsigner):
    verification = run([jarsigner, '-J-Duser.language=en', '-J-Duser.country=US', '-verify', path])
    require('jar verified.' in verification and 'unsigned entries' not in verification,
            'AAB JAR signature is missing or incomplete.')
    cert_output = run([keytool, '-J-Duser.language=en', '-printcert', '-jarfile', path])
    certs = re.findall(r'SHA256:\s*([A-Fa-f0-9:]+)', cert_output)
    require(len(certs) == 1 and DIGEST.fullmatch(certs[0].replace(':', '')), 'AAB signer cannot be confirmed.')
    manifest = ET.fromstring(run([java, '-jar', bundletool, 'dump', 'manifest', '--bundle', path]))
    android = '{http://schemas.android.com/apk/res/android}'
    application = manifest.find('application')
    require(application is not None, 'AAB manifest lacks application.')
    debug = application.get(android + 'debuggable', 'false')
    require(debug in ('false', 'true'), 'AAB debuggable flag is not a literal.')
    with zipfile.ZipFile(path) as archive:
        abis = {p.split('/')[2] for p in archive.namelist() if p.startswith('base/lib/') and p.endswith('.so')}
    return {'applicationId': manifest.get('package'), 'versionName': manifest.get(android + 'versionName'),
            'versionCode': int(manifest.get(android + 'versionCode', '0')), 'debuggable': debug == 'true',
            'abis': sorted(abis), 'certificateSha256': certs[0].replace(':', '').lower()}


def require_clean_source():
    require(not run(['git', 'diff', 'HEAD', '--name-only']).strip(),
            'Commit tracked changes before candidate packaging.')
    untracked = run(['git', 'ls-files', '--others', '--exclude-standard', '--',
                     'lib', 'assets', 'android', 'ios', 'tools', 'pubspec.yaml', 'pubspec.lock']).strip()
    require(not untracked, 'Untracked build inputs must be reviewed and committed before packaging.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True, help='Reviewed historical APK paths and hashes (local JSON).')
    parser.add_argument('--validate-only', action='store_true', help='Preflight only; does not validate a new artifact.')
    parser.add_argument('--with-aab', action='store_true')
    parser.add_argument('--bundletool', type=Path, help='Required only with --with-aab.')
    args = parser.parse_args()
    os.chdir(ROOT)
    stable = stable_manifest(ROOT)
    name, code = candidate_version(ROOT)
    tools = {name: tool(name) for name in ('java', 'aapt', 'apksigner', 'flutter')}
    if args.with_aab:
        require(args.bundletool and args.bundletool.is_file(), '--with-aab requires an existing bundletool JAR.')
        tools.update({name: tool(name) for name in ('keytool', 'jarsigner')})
    baseline = json.loads(args.baseline.read_text())
    records = validate_baseline(baseline, args.baseline.resolve().parent, lambda p: inspect_apk(p, tools))
    validate_candidate(name, code, records, stable)
    run([tools['java'], ROOT / 'tools/release/SigningConfigCheck.java', ROOT / 'android'])
    head = run(['git', 'rev-parse', 'HEAD']).strip()
    # Untracked private records are not source inputs, but tracked changes must be reviewed/committed.
    require_clean_source()
    print('Preflight passed for the supplied historical scope. Stable manifests unchanged.')
    if args.validate_only:
        return
    run([tools['flutter'], 'pub', 'get', '--enforce-lockfile'], capture=False)
    run([tools['flutter'], 'analyze', '--no-pub'], capture=False)
    run([tools['flutter'], 'test', '--no-pub'], capture=False)
    outputs = [('apk', ROOT / 'build/app/outputs/flutter-apk/app-release.apk')]
    if args.with_aab:
        outputs.append(('appbundle', ROOT / 'build/app/outputs/bundle/release/app-release.aab'))
    for kind, output in outputs:
        output.unlink(missing_ok=True)  # Only the exact expected build output, never a directory glob.
        run([tools['flutter'], 'build', kind, '--release', '--no-pub',
             '--target-platform', 'android-arm64,android-x64'], capture=False)
        require(output.is_file(), 'Expected fresh build output is missing.')
    report_root = ROOT / 'build/release-verification'
    report_root.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix=f'{name}-{code}-', dir=report_root))
    report = {'schemaVersion': 1, 'sourceCommit': head, 'version': name, 'buildNumber': code,
              'upgradeScope': baseline['scope'], 'historicalArtifacts': records,
              'flutter': run([tools['flutter'], '--version']).strip(),
              'aapt': run([tools['aapt'], 'version']).strip(),
              'apksigner': run([tools['apksigner'], 'version']).strip(), 'artifacts': []}
    for kind, output in outputs:
        record = inspect_apk(output, tools) if kind == 'apk' else inspect_aab(
            output, args.bundletool.resolve(), tools['java'], tools['keytool'], tools['jarsigner'])
        validate_artifact(record, name, code, records[0]['certificateSha256'])
        target = destination / output.name
        shutil.copyfile(output, target)
        report['artifacts'].append(dict(record, name=target.name, size=target.stat().st_size, sha256=sha256(target)))
    require(run(['git', 'rev-parse', 'HEAD']).strip() == head, 'Source changed during packaging.')
    require_clean_source()
    require(stable_manifest(ROOT) == stable, 'Stable manifest changed during candidate build.')
    (destination / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'Candidate verified: {destination.relative_to(ROOT)}. Not uploaded or released.')


if __name__ == '__main__':
    try:
        main()
    except (ValidationError, OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, ET.ParseError) as error:
        # Keep filesystem/decoder details out of signing output.
        print(str(error) if isinstance(error, ValidationError) else 'Release input or tooling failed; no verified release.', file=sys.stderr)
        sys.exit(1)
