import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import android_release as r
import prepare_stable_manifest as m

CERT = 'a' * 64

# Historical test input is independent of whichever stable version is published.
STABLE_FIXTURE = {
    'version': '2.1.4', 'release_date': '2026-09-28', 'changelog': ['fixture'],
    'downloads': {'github': f'{r.RELEASES}/download/v2.1.4/app-release.apk'},
}



def metadata(code=5000, version='2.2.0', abis=None):
    return {'applicationId': r.APP_ID, 'versionName': version, 'versionCode': code,
            'debuggable': False, 'abis': sorted(r.ABIS if abis is None else abis), 'certificateSha256': CERT}


def report():
    apk = dict(metadata(), name='app-release.apk', size=7, sha256='b' * 64)
    return {'schemaVersion': 1, 'version': '2.2.0', 'buildNumber': 5000, 'artifacts': [apk]}


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        original_cwd = Path.cwd()
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.addCleanup(os.chdir, original_cwd)
        self.root = Path(self.directory.name).resolve()

    def baseline(self):
        records = [metadata(6, '2.1.4'), metadata(2006, '2.1.4', {'arm64-v8a'}),
                   metadata(4006, '2.1.4', {'x86_64'})]
        assets, lookup = [], {}
        for i, record in enumerate(records):
            path = self.root / f'old {i}.apk'
            path.write_bytes(f'fixture {i}'.encode())
            assets.append({'path': path.name, 'sha256': r.sha256(path)})
            lookup[path] = record
        return {'schemaVersion': 1, 'scope': 'fixtures only', 'artifacts': assets}, lookup

    def test_baseline_reads_all_actual_paths_and_digests(self):
        data, lookup = self.baseline()
        result = r.validate_baseline(data, self.root, lookup.__getitem__)
        self.assertEqual(max(v['versionCode'] for v in result), 4006)
        self.assertEqual(len(result), 3)

    def test_baseline_rejects_invented_hash_missing_duplicate_and_omitted_variants(self):
        for case in ['hash', 'missing', 'duplicate', 'omission', 'scope']:
            with self.subTest(case=case):
                data, lookup = self.baseline()
                if case == 'hash': data['artifacts'][0]['sha256'] = 'f' * 64
                if case == 'missing': data['artifacts'][0]['path'] = 'missing.apk'
                if case == 'duplicate': data['artifacts'].append(data['artifacts'][0])
                if case == 'omission': data['artifacts'].pop()
                if case == 'scope': data['scope'] = ''
                with self.assertRaises(r.ValidationError): r.validate_baseline(data, self.root, lookup.__getitem__)

    def test_baseline_rejects_debug_different_identity_and_certificates(self):
        for field, value in [('debuggable', True), ('applicationId', 'com.flandresy.debug'), ('certificateSha256', 'c' * 64)]:
            with self.subTest(field=field):
                data, lookup = self.baseline()
                next(iter(lookup.values()))[field] = value
                with self.assertRaises(r.ValidationError): r.validate_baseline(data, self.root, lookup.__getitem__)

    def test_version_code_accounts_for_historical_max_beyond_known_4006(self):
        records = [metadata(4006), metadata(9000)]
        with self.assertRaises(r.ValidationError): r.validate_candidate('2.2.0', 5000, records, {'version': '2.1.4'})
        r.validate_candidate('2.2.0', 9001, records, {'version': '2.1.4'})

    def test_candidate_rejects_equal_lower_code_lower_name_and_boolean_code(self):
        for name, code in [('2.2.0', 4006), ('2.2.0', 7), ('2.0.0', 5000), ('2.2.0', True), ('2.2.0', 2100000001)]:
            with self.subTest(name=name, code=code):
                with self.assertRaises(r.ValidationError):
                    r.validate_candidate(name, code, [metadata(4006, '2.1.4')], {'version': '2.1.4'})

    def test_actual_artifact_identity_is_verified(self):
        r.validate_artifact(metadata(), '2.2.0', 5000, CERT)
        for field, value in [('applicationId', 'other'), ('versionName', '2.1.4'), ('versionCode', 7),
                             ('debuggable', True), ('abis', ['arm64-v8a']), ('certificateSha256', 'd' * 64)]:
            with self.subTest(field=field):
                altered = metadata(); altered[field] = value
                with self.assertRaises(r.ValidationError): r.validate_artifact(altered, '2.2.0', 5000, CERT)

    def test_apk_tool_parser_detects_debug_and_multiple_signers(self):
        text = "package: name='com.flandresy' versionCode='5000' versionName='2.2.0' platformBuildVersionName=''\nnative-code: 'arm64-v8a' 'x86_64'\n"
        cert = f'Signer #1 certificate SHA-256 digest: {CERT}\n'
        self.assertEqual(r.apk_metadata(text, cert), metadata())
        self.assertTrue(r.apk_metadata(text + 'application-debuggable\n', cert)['debuggable'])
        for badging, certificates in [(text.replace('native-code:', 'missing:'), cert), (text, ''), (text, cert + cert)]:
            with self.assertRaises(r.ValidationError): r.apk_metadata(badging, certificates)

    def test_failed_native_tool_does_not_echo_secret_diagnostics(self):
        with self.assertRaises(r.ValidationError) as error:
            r.run([sys.executable, '-c', 'import sys; print("private password"); sys.exit(1)'])
        self.assertNotIn('private password', str(error.exception))

    def inspect_flutter_fixture(self, libraries, native_abis=None):
        path = self.root / 'flutter.apk'
        with zipfile.ZipFile(path, 'w') as archive:
            for name, content in libraries.items(): archive.writestr(name, content)
        native_abis = native_abis or ['arm64-v8a', 'armeabi-v7a', 'x86_64']
        badging = ("package: name='com.flandresy' versionCode='5000' versionName='2.2.0'\n"
                   + 'native-code: ' + ' '.join(f"'{abi}'" for abi in native_abis) + '\n')
        with patch.object(r, 'run', side_effect=[badging, f'Signer #1 certificate SHA-256 digest: {CERT}\n']):
            return r.inspect_apk(path, {'aapt': 'aapt', 'apksigner': 'apksigner'})

    def flutter_libraries(self, abis=None):
        return {f'lib/{abi}/{name}': b'fixture' for abi in (abis or r.ABIS)
                for name in ('libapp.so', 'libflutter.so')}

    def test_dependency_only_abi_does_not_count_as_flutter_runtime(self):
        libraries = self.flutter_libraries()
        libraries['lib/armeabi-v7a/libscanner.so'] = b'dependency'
        value = self.inspect_flutter_fixture(libraries)
        self.assertEqual(value['abis'], sorted(r.ABIS))
        self.assertEqual(value['nativeAbis'], ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
        r.validate_artifact(value, '2.2.0', 5000, CERT)
        # This inspected universal layout also satisfies the historical scope.
        data, lookup = self.baseline()
        lookup[next(iter(lookup))] = dict(value, versionCode=6, versionName='2.1.4')
        self.assertEqual(len(r.validate_baseline(data, self.root, lookup.__getitem__)), 3)

    def test_incomplete_empty_or_undeclared_flutter_runtime_is_rejected(self):
        for case in ('engine_missing', 'app_missing', 'no_flutter', 'empty', 'undeclared'):
            with self.subTest(case=case):
                libraries = self.flutter_libraries()
                native_abis = None
                if case == 'engine_missing': del libraries['lib/x86_64/libflutter.so']
                if case == 'app_missing': del libraries['lib/x86_64/libapp.so']
                if case == 'no_flutter': libraries = {'lib/arm64-v8a/libscanner.so': b'dependency'}
                if case == 'empty': libraries['lib/arm64-v8a/libflutter.so'] = b''
                if case == 'undeclared': native_abis = ['arm64-v8a']
                with self.assertRaises(r.ValidationError):
                    self.inspect_flutter_fixture(libraries, native_abis)

    def test_complete_extra_or_missing_target_flutter_abi_still_fails_candidate(self):
        for abis in ({'arm64-v8a'}, {'arm64-v8a', 'x86_64', 'armeabi-v7a'}):
            with self.subTest(abis=abis):
                value = self.inspect_flutter_fixture(self.flutter_libraries(abis))
                with self.assertRaises(r.ValidationError):
                    r.validate_artifact(value, '2.2.0', 5000, CERT)

    def test_required_tool_missing_fails_closed(self):
        with patch.dict(os.environ, {'PATH': '', 'ANDROID_HOME': str(self.root), 'ANDROID_SDK_ROOT': str(self.root)}):
            with self.assertRaises(r.ValidationError): r.tool('aapt')

    def test_candidate_metadata_is_independent_of_published_version(self):
        (self.root / 'pubspec.yaml').write_text('name: demo\nversion: 2.2.0+5000\n')
        self.assertEqual(r.candidate_version(self.root), ('2.2.0', 5000))
        for value in ['2.2+5', 'abc+5', '2.2.0+-1', '2.2.0+0', '2.2.0-beta+5']:
            (self.root / 'pubspec.yaml').write_text(f'version: {value}\n')
            with self.assertRaises(r.ValidationError): r.candidate_version(self.root)

    def test_stable_copies_must_match_and_remain_unchanged(self):
        source = r.ROOT / 'assets/public/version.json'
        for target in ['assets/public/version.json', 'public/version.json']:
            path = self.root / target; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(STABLE_FIXTURE))
        before = source.read_bytes()
        self.assertEqual(r.stable_manifest(self.root)['version'], '2.1.4')
        (self.root / 'public/version.json').write_text('{}')
        with self.assertRaises(r.ValidationError): r.stable_manifest(self.root)
        self.assertEqual(source.read_bytes(), before)

    def test_aab_signature_and_metadata_checked_separately(self):
        path = self.root / 'app.aab'
        with zipfile.ZipFile(path, 'w') as archive:
            for abi in r.ABIS: archive.writestr(f'base/lib/{abi}/libapp.so', b'fixture')
        xml = '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.flandresy" android:versionCode="5000" android:versionName="2.2.0"><application android:debuggable="false"/></manifest>'
        outputs = ['jar verified.', f'SHA256: {CERT}', xml]
        with patch.object(r, 'run', side_effect=outputs):
            self.assertEqual(r.inspect_aab(path, 'bundletool', 'java', 'keytool', 'jarsigner'), metadata())
        with patch.object(r, 'run', return_value='jar is unsigned.'):
            with self.assertRaises(r.ValidationError): r.inspect_aab(path, 'bundletool', 'java', 'keytool', 'jarsigner')
        with patch.object(r, 'run', return_value='jar verified. contains unsigned entries'):
            with self.assertRaises(r.ValidationError): r.inspect_aab(path, 'bundletool', 'java', 'keytool', 'jarsigner')

    def test_prepare_manifest_keeps_old_client_fields_and_ios_unavailable(self):
        value = m.make_manifest(report(), {'release_date': '2026-10-17', 'changelog': ['中文']})
        self.assertEqual(value['downloads']['github'], value['platforms']['android']['downloadUrl'])
        self.assertEqual(value['platforms']['ios'], {'status': 'unavailable'})
        self.assertEqual(value['version'], '2.2.0')
        with self.assertRaises(r.ValidationError): m.make_manifest(report(), {'changelog': [5]})

    def test_public_release_must_be_stable_and_asset_match_verified_bytes(self):
        data = report(); manifest = m.make_manifest(data, {'release_date': '', 'changelog': []})
        release = {'tag_name': 'v2.2.0', 'draft': False, 'prerelease': False, 'assets': [
            {'name': 'app-release.apk', 'state': 'uploaded', 'size': 7, 'browser_download_url': manifest['downloads']['github']}]}
        m.verify_public(data, manifest, release, lambda _: 'b' * 64)
        for key, value in [('draft', True), ('prerelease', True), ('tag_name', 'v2.3.0'), ('assets', [])]:
            altered = copy.deepcopy(release); altered[key] = value
            with self.assertRaises(r.ValidationError): m.verify_public(data, manifest, altered, lambda _: 'b' * 64)
        with self.assertRaises(r.ValidationError): m.verify_public(data, manifest, release, lambda _: 'c' * 64)

    def test_signing_properties_support_absolute_relative_spaces_unicode_and_continuations(self):
        java = shutil.which('java')
        self.assertIsNotNone(java, 'JDK 17 is required for release tooling tests')
        android = self.root / 'android'; android.mkdir()
        key = android / 'keys' / 'release key.jks'; key.parent.mkdir(); key.write_text('fixture, not a real key')
        cases = ['keys/release key.jks', str(key), 'keys/release\\ key.jks', 'keys/release\\u0020key.jks', 'keys/\\\n release key.jks']
        for path in cases:
            with self.subTest(path=path):
                (android / 'key.properties').write_text('# fixture\nstoreFile : ' + path + '\nstorePassword=secret\nkeyAlias=fixture\nkeyPassword=secret\n')
                result = subprocess.run([java, str(TOOLS / 'SigningConfigCheck.java'), str(android)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn('secret', result.stdout + result.stderr)
                self.assertNotIn(str(self.root), result.stdout + result.stderr)

    def test_signing_missing_file_fields_and_malformed_properties_fail_without_secrets(self):
        android = self.root / 'android'; android.mkdir()
        for content in [None, 'storeFile=missing.jks\nstorePassword=secret\nkeyAlias=x\nkeyPassword=secret',
                        'storeFile=secret', 'storeFile=\\uXXXX\nsecret=password']:
            if content is not None: (android / 'key.properties').write_text(content)
            result = subprocess.run(['java', str(TOOLS / 'SigningConfigCheck.java'), str(android)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('secret', result.stdout + result.stderr)
            self.assertNotIn(str(self.root), result.stdout + result.stderr)

    def pipeline(self, *, with_aab=False, no_output=False, wrong_cert=False):
        baseline, lookup = self.baseline()
        (self.root / 'baseline.json').write_text(json.dumps(baseline))
        (self.root / 'pubspec.yaml').write_text('version: 2.2.0+5000\n')
        for name in ['assets/public/version.json', 'public/version.json']:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(STABLE_FIXTURE))
        commands = []
        def fake_run(args, capture=True):
            commands.append([str(a) for a in args])
            if args[:3] == ['git', 'rev-parse', 'HEAD']: return 'd' * 40
            if args[:2] == ['flutter', 'build']:
                suffix = 'flutter-apk/app-release.apk' if args[2] == 'apk' else 'bundle/release/app-release.aab'
                target = self.root / 'build/app/outputs' / suffix
                self.assertFalse(target.exists(), 'stale expected output must be removed first')
                if not no_output:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text('new candidate fixture')
            return ''
        def inspect(path, *args):
            if path in lookup: return lookup[path]
            value = metadata()
            if wrong_cert: value['certificateSha256'] = 'e' * 64
            return value
        old = self.root / 'build/app/outputs/flutter-apk/app-release.apk'
        old.parent.mkdir(parents=True, exist_ok=True); old.write_text('stale candidate')
        extra = old.parent / 'app-arm64-v8a-release.apk'; extra.write_text('unrelated old split')
        bundle = self.root / 'bundletool.jar'; bundle.write_text('fixture')
        argv = ['release', '--baseline', str(self.root / 'baseline.json')]
        if with_aab: argv += ['--with-aab', '--bundletool', str(bundle)]
        before = (self.root / 'assets/public/version.json').read_bytes()
        with patch.object(r, 'ROOT', self.root), patch.object(r, 'tool', side_effect=lambda x: x), \
                patch.object(r, 'run', side_effect=fake_run), patch.object(r, 'inspect_apk', side_effect=inspect), \
                patch.object(r, 'inspect_aab', side_effect=inspect), patch.object(sys, 'argv', argv):
            r.main()
        self.assertEqual(before, (self.root / 'assets/public/version.json').read_bytes())
        self.assertEqual(extra.read_text(), 'unrelated old split')
        reports = list((self.root / 'build/release-verification').glob('*/verification.json'))
        self.assertEqual(len(reports), 1)
        return json.loads(reports[0].read_text()), commands

    def test_pipeline_builds_only_fresh_universal_and_never_changes_stable(self):
        data, commands = self.pipeline()
        self.assertEqual([v['name'] for v in data['artifacts']], ['app-release.apk'])
        self.assertIn(['flutter', 'pub', 'get', '--enforce-lockfile'], commands)
        self.assertNotIn('--split-per-abi', sum(commands, []))
        self.assertEqual(data['sourceCommit'], 'd' * 40)

    def test_pipeline_aab_is_explicit_and_separately_reported(self):
        data, _ = self.pipeline(with_aab=True)
        self.assertEqual([v['name'] for v in data['artifacts']], ['app-release.apk', 'app-release.aab'])

    def test_successful_build_without_output_cannot_report_stale_apk(self):
        with self.assertRaises(r.ValidationError): self.pipeline(no_output=True)
        self.assertEqual(list(self.root.glob('build/release-verification/*/verification.json')), [])

    def test_pipeline_wrong_signing_certificate_cannot_report_success(self):
        with self.assertRaises(r.ValidationError): self.pipeline(wrong_cert=True)
        self.assertEqual(list(self.root.glob('build/release-verification/*/verification.json')), [])

    def test_untracked_build_input_or_tracked_edit_blocks_source_attribution(self):
        with patch.object(r, 'run', return_value='lib/untracked.dart'):
            with self.assertRaises(r.ValidationError): r.require_clean_source()
        with patch.object(r, 'run', side_effect=['', 'lib/untracked.dart']):
            with self.assertRaises(r.ValidationError): r.require_clean_source()


if __name__ == '__main__':
    unittest.main()
