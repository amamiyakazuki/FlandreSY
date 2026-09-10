import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

@immutable
class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.releaseDate,
    required this.changelog,
    required this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'];
    final github = downloads is Map ? (downloads['github'] ?? '') : '';
    final changelog = json['changelog'];
    return VersionInfo(
      version: (json['version'] ?? '').toString(),
      releaseDate: (json['release_date'] ?? '').toString(),
      changelog: changelog is List
          ? changelog.map((entry) => entry.toString()).toList(growable: false)
          : const <String>[],
      downloadUrl: github.toString(),
    );
  }

  final String version;
  final String releaseDate;
  final List<String> changelog;
  final String downloadUrl;
}

@immutable
class VersionCheckResult {
  const VersionCheckResult({
    required this.current,
    required this.latest,
    required this.hasUpdate,
    this.error,
  });

  final String current;
  final VersionInfo? latest;
  final bool hasUpdate;
  final String? error;

  bool get failed => error != null;
}

const String kCurrentAppVersion = '2.1.1';
const String kVersionManifestAsset = 'assets/public/version.json';
const String kVersionManifestUrl =
    'https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/assets/public/version.json';

Future<String> currentAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.trim().isNotEmpty) return info.version.trim();
  } catch (_) {
    // Flutter tests and platforms without package metadata use the build fallback.
  }
  return kCurrentAppVersion;
}

Future<VersionCheckResult> checkLatestVersion({
  http.Client? client,
  String? currentVersion,
  Uri? manifestUri,
}) async {
  final current = currentVersion ?? await currentAppVersion();
  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(manifestUri ?? Uri.parse(kVersionManifestUrl))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return VersionCheckResult(
        current: current,
        latest: null,
        hasUpdate: false,
        error: '版本清单请求失败（${response.statusCode}），请稍后重试。',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('version manifest is not an object');
    }
    final latest = VersionInfo.fromJson(decoded);
    if (latest.version.trim().isEmpty || latest.downloadUrl.trim().isEmpty) {
      throw const FormatException('version manifest is incomplete');
    }
    return VersionCheckResult(
      current: current,
      latest: latest,
      hasUpdate: compareSemver(latest.version, current) > 0,
    );
  } on FormatException {
    return VersionCheckResult(
      current: current,
      latest: null,
      hasUpdate: false,
      error: '版本清单格式无效，请稍后重试。',
    );
  } catch (_) {
    return VersionCheckResult(
      current: current,
      latest: null,
      hasUpdate: false,
      error: '检查更新失败，请检查网络后重试。',
    );
  } finally {
    if (ownedClient) httpClient.close();
  }
}

/// 兼容旧调用名，实际执行真实远程检查。
Future<VersionCheckResult> checkLatestVersionFake() => checkLatestVersion();

int compareSemver(String a, String b) {
  try {
    return Version.parse(a.trim()).compareTo(Version.parse(b.trim()));
  } catch (_) {
    return _compareNumericFallback(a, b);
  }
}

int _compareNumericFallback(String a, String b) {
  final pa = a.split(RegExp(r'[.+-]'));
  final pb = b.split(RegExp(r'[.+-]'));
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
    final vb = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}
