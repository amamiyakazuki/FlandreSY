import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flandresy/src/more/version_check.dart';

Map<String, dynamic> manifest({String version = '2.2.0', int? build = 5000}) {
  final url = '$kReleasePage/download/v$version/app-release.apk';
  return {
    'version': version,
    'release_date': '2026-10-17',
    'changelog': ['修复更新'],
    'downloads': {'github': url},
    if (build != null) ...{
      'schemaVersion': 2,
      'platforms': {
        'android': {
          'status': 'available',
          'version': version,
          'buildNumber': build,
          'downloadUrl': url
        },
        'ios': {'status': 'unavailable'}
      }
    }
  };
}

Future<VersionCheckResult> check(
  Map<String, dynamic> data, {
  String? version = '2.1.4',
  int? build = 4006,
  String? package = 'com.flandresy',
  TargetPlatform platform = TargetPlatform.android,
}) =>
    checkLatestVersion(
        installed: InstalledAppInfo(
            version: version, buildNumber: build, packageName: package),
        platform: platform,
        client: MockClient((_) async =>
            http.Response.bytes(utf8.encode(jsonEncode(data)), 200)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reads real package metadata including build and identity', () async {
    final value = await InstalledAppInfo.read(
        loader: () async => PackageInfo(
            appName: 'test',
            packageName: 'com.flandresy',
            version: '2.1.4',
            buildNumber: '4006'));
    expect(value.version, '2.1.4');
    expect(value.buildNumber, 4006);
    expect(value.packageName, 'com.flandresy');
  });
  for (final version in ['', '2.1', 'garbage']) {
    test('invalid package version remains unknown: $version', () async {
      final value = await InstalledAppInfo.read(
          loader: () async => PackageInfo(
              appName: 'test',
              packageName: 'com.flandresy',
              version: version,
              buildNumber: '6'));
      expect(value.displayVersion, '未知');
    });
  }
  test('package lookup failure never guesses an old version', () async {
    expect(
        (await InstalledAppInfo.read(
                loader: () async => throw StateError('unavailable')))
            .displayVersion,
        '未知');
  });
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux
  ]) {
    test('$platform has no APK update and makes no network request', () async {
      final result = await checkLatestVersion(
          platform: platform,
          installed: const InstalledAppInfo(),
          client:
              MockClient((_) async => throw StateError('must not request')));
      expect(result.state, UpdateState.noChannel);
      expect(result.hasUpdate, false);
      expect(result.actionUrl, kReleasePage);
    });
  }
  test('unknown local metadata does not fetch or claim latest', () async {
    final result = await checkLatestVersion(
        platform: TargetPlatform.android,
        installed: const InstalledAppInfo(),
        client: MockClient((_) async => throw StateError('must not request')));
    expect(result.state, UpdateState.unknown);
    expect(result.actionUrl, null);
  });
  for (final build in [6, 2006, 4006]) {
    test('new universal code can supersede old package $build', () async {
      final result = await check(manifest(), build: build);
      expect(result.state, UpdateState.available);
      expect(result.actionUrl, endsWith('app-release.apk'));
    });
  }
  test('same displayed version with greater code offers update', () async {
    expect(
        (await check(manifest(version: '2.1.4'))).state, UpdateState.available);
  });
  test('equal version and code has no update', () async {
    expect((await check(manifest(version: '2.1.4', build: 4006))).state,
        UpdateState.current);
  });
  test('higher installed version does not offer downgrade', () async {
    final result = await check(manifest(), version: '3.0.0');
    expect(result.state, UpdateState.newer);
    expect(result.actionUrl, null);
  });
  for (final code in [7, 4006]) {
    test('higher marketing version alone cannot bypass code $code', () async {
      final result = await check(manifest(build: code));
      expect(result.state, UpdateState.reviewRelease);
      expect(result.actionUrl, endsWith('/tag/v2.2.0'));
    });
  }
  test(
      'legacy manifest remains readable but cannot promise compatible download',
      () async {
    final result = await check(manifest(build: null));
    expect(result.state, UpdateState.reviewRelease);
    expect(result.latest!.version, '2.2.0');
  });
  for (final code in [null, 0, -1]) {
    test('unknown local build $code cannot directly download', () async {
      expect((await check(manifest(), build: code)).state,
          UpdateState.reviewRelease);
    });
  }
  for (final package in [null, 'other.app', 'com.flandresy.debug']) {
    test('non-production identity $package provides release information only',
        () async {
      expect((await check(manifest(), package: package)).state,
          UpdateState.reviewRelease);
    });
  }
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'number version': (v) => v['version'] = 2,
    'partial version': (v) => v['version'] = '2.2',
    'leading zero version': (v) => v['version'] = '02.2.0',
    'noninteger schema': (v) => v['schemaVersion'] = 2.0,
    'invalid version': (v) => v['version'] = 'abc',
    'prerelease stable': (v) => v['version'] = '2.2.0-beta',
    'build version stable': (v) => v['version'] = '2.2.0+5',
    'bad date': (v) => v['release_date'] = [],
    'missing changes': (v) => v.remove('changelog'),
    'typed changes': (v) => v['changelog'] = [3],
    'missing url': (v) => v['downloads'] = {},
    'unknown schema': (v) => v['schemaVersion'] = 3,
    'missing platforms': (v) => v.remove('platforms'),
    'string code': (v) => v['platforms']['android']['buildNumber'] = '5000',
    'negative code': (v) => v['platforms']['android']['buildNumber'] = -1,
    'huge code': (v) => v['platforms']['android']['buildNumber'] = 2100000001,
    'different platform version': (v) =>
        v['platforms']['android']['version'] = '8.0.0',
    'different platform link': (v) =>
        v['platforms']['android']['downloadUrl'] = 'https://evil.com/file.apk',
    'ios should not acquire channel': (v) =>
        v['platforms']['ios']['status'] = 'available',
  };
  invalid.forEach((name, mutate) {
    test('invalid manifest rejects $name', () async {
      final data = manifest();
      mutate(data);
      final result = await check(data);
      expect(result.state, UpdateState.failure);
      expect(result.actionUrl, null);
    });
  });
  for (final url in [
    'http://github.com/amamiyakazuki/FlandreSY/releases/download/v2.2.0/app-release.apk',
    'https://evil.com/file.apk',
    'https://github.com.evil.com/app.apk',
    'file:///tmp/app.apk',
    '$kReleasePage/download/v2.1.4/app-release.apk',
    '$kReleasePage/download/v2.2.0/app-arm64-v8a-release.apk',
    '$kReleasePage/download/v2.2.0/app-release.apk?foo=bar',
    'https://user@github.com/amamiyakazuki/FlandreSY/releases',
    'https://github.com:444/amamiyakazuki/FlandreSY/releases'
  ]) {
    test('reject untrusted or inconsistent URL $url', () async {
      final data = manifest(build: null);
      data['downloads'] = {'github': url};
      expect((await check(data)).failed, true);
    });
  }
  for (final body in ['[]', 'null', '{', 'true']) {
    test('invalid JSON/object $body never claims current', () async {
      final result = await checkLatestVersion(
          platform: TargetPlatform.android,
          installed: const InstalledAppInfo(version: '2.1.4'),
          client: MockClient((_) async => http.Response(body, 200)));
      expect(result.failed, true);
    });
  }
  test('timeout and network exceptions are retryable', () async {
    for (final client in [
      MockClient((_) => Completer<http.Response>().future),
      MockClient((_) async => throw http.ClientException('offline'))
    ]) {
      final result = await checkLatestVersion(
          platform: TargetPlatform.android,
          installed: const InstalledAppInfo(version: '2.1.4'),
          client: client,
          timeout: const Duration(milliseconds: 1));
      expect(result.failed, true);
    }
    expect((await check(manifest())).failed, false);
  });
  test('strict semver handles prerelease and rejects numeric guessing', () {
    expect(compareSemver('2.2.0-beta', '2.2.0'), lessThan(0));
    expect(() => compareSemver('bad', '2.1.4'), throwsFormatException);
  });
}
