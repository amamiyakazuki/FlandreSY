#!/usr/bin/env python3
"""Prepare a compatible stable manifest ONLY after public release verification.
Writes a candidate JSON beside the verification report; never edits online/local stable files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

from android_release import (ROOT, RELEASES, APP_ID, ABIS, DIGEST, ValidationError,
                             require, sha256, positive_code, version_tuple)


def make_manifest(report, notes):
    version_tuple(report.get('version'))
    code = report.get('buildNumber')
    require(positive_code(code) and code > 4006, 'Candidate must exceed the known historical package codes.')
    require(report.get('schemaVersion') == 1 and isinstance(report.get('artifacts'), list), 'Missing verification report.')
    apks = [a for a in report['artifacts'] if a.get('name') == 'app-release.apk']
    require(len(apks) == 1, 'Report must contain one universal APK.')
    apk = apks[0]
    require(apk.get('applicationId') == APP_ID and apk.get('versionName') == report['version'] and
            apk.get('versionCode') == code and apk.get('debuggable') is False and
            set(apk.get('abis', [])) == ABIS and DIGEST.fullmatch(apk.get('sha256', '')) and
            DIGEST.fullmatch(apk.get('certificateSha256', '')), 'Invalid verified APK metadata.')
    require(isinstance(notes.get('release_date'), str) and isinstance(notes.get('changelog'), list) and
            all(isinstance(v, str) for v in notes['changelog']), 'Release notes require date and text changelog.')
    url = f"{RELEASES}/download/v{report['version']}/app-release.apk"
    return {'version': report['version'], 'release_date': notes['release_date'], 'changelog': notes['changelog'],
            'downloads': {'github': url}, 'schemaVersion': 2,
            'platforms': {'android': {'status': 'available', 'version': report['version'], 'buildNumber': code,
                                      'downloadUrl': url}, 'ios': {'status': 'unavailable'}}}


def public_hash(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'FlandreSY-release-verifier'})
    digest = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=30) as response:
        require(response.status == 200, 'Public asset is not available.')
        for chunk in iter(lambda: response.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def verify_public(report, manifest, release, hash_reader=public_hash):
    require(release.get('tag_name') == 'v' + report['version'] and release.get('draft') is False and
            release.get('prerelease') is False, 'Release must already be public and stable.')
    matching = [a for a in release.get('assets', []) if a.get('name') == 'app-release.apk' and
                a.get('browser_download_url') == manifest['downloads']['github'] and a.get('state') == 'uploaded']
    require(len(matching) == 1, 'Public universal APK is missing.')
    apk = next(a for a in report['artifacts'] if a['name'] == 'app-release.apk')
    require(matching[0].get('size') == apk['size'] and
            hash_reader(manifest['downloads']['github']) == apk['sha256'], 'Public APK differs from the verified candidate.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--notes', type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    manifest = make_manifest(report, json.loads(args.notes.read_text()))
    apk = next(a for a in report['artifacts'] if a['name'] == 'app-release.apk')
    require(sha256(args.report.parent / 'app-release.apk') == apk['sha256'], 'Local candidate changed after verification.')
    api = f"https://api.github.com/repos/amamiyakazuki/FlandreSY/releases/tags/v{report['version']}"
    request = urllib.request.Request(api, headers={'User-Agent': 'FlandreSY-release-verifier'})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    verify_public(report, manifest, release)
    output = args.report.parent / 'stable-manifest.candidate.json'
    require(output.resolve() not in {(ROOT / 'assets/public/version.json').resolve(),
                                     (ROOT / 'public/version.json').resolve()}, 'Cannot overwrite stable files.')
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('Public asset verified. Candidate manifest written; review and copy to BOTH stable paths only with release authorization.')


if __name__ == '__main__':
    try:
        main()
    except (ValidationError, OSError, ValueError, KeyError, TypeError):
        print('Stable manifest preparation failed; stable files unchanged.', file=sys.stderr)
        sys.exit(1)
