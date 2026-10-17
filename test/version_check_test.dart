import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flandresy/src/more/version_check.dart';

void main() {
  test('semver comparison handles prerelease and patch versions', () {
    expect(compareSemver('2.1.0', '2.0.9'), greaterThan(0));
    expect(compareSemver('2.1.0-beta', '2.1.0'), lessThan(0));
    expect(compareSemver('2.1.0', '2.1.0'), 0);
  });

  test('remote manifest reports an available update', () async {
    final result = await checkLatestVersion(
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(
              '{"version":"2.2.0","release_date":"2026-10-01",'
              '"changelog":["修复问题"],"downloads":{"github":"https://github.com/amamiyakazuki/FlandreSY/releases/download/v2.2.0/app-release.apk"}}',
            ),
            200,
          )),
      installed: const InstalledAppInfo(
          version: '2.1.0', buildNumber: 1, packageName: 'com.flandresy'),
      platform: TargetPlatform.android,
      manifestUri: Uri.parse('https://example.com/version.json'),
    );

    expect(result.error, isNull, reason: result.error);
    expect(result.failed, isFalse);
    expect(result.state, UpdateState.reviewRelease);
    expect(result.actionLabel, '查看发布说明');
    expect(result.latest?.downloadUrl,
        'https://github.com/amamiyakazuki/FlandreSY/releases/download/v2.2.0/app-release.apk');
  });

  test('non-success response is retryable failure', () async {
    final result = await checkLatestVersion(
      client:
          MockClient((_) async => http.Response('service unavailable', 503)),
      installed: const InstalledAppInfo(
          version: '2.1.0', buildNumber: 1, packageName: 'com.flandresy'),
      platform: TargetPlatform.android,
      manifestUri: Uri.parse('https://example.com/version.json'),
    );

    expect(result.failed, isTrue);
    expect(result.latest, isNull);
    expect(result.error, contains('503'));
  });
}
