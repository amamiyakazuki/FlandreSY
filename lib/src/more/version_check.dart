// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Version check (no visual constants). Fake: compares a bundled/inlined latest version against
// the current app version via semver. Real HTTP fetch of public/version.json is deferred to stage 4.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 版本清单信息（对齐 legacy public/version.json 结构）。
@immutable
class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.releaseDate,
    required this.changelog,
    required this.downloadUrl,
  });

  /// 从 version.json 结构解析（对齐 legacy：version/release_date/changelog/downloads.github）。
  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'];
    final github = downloads is Map ? (downloads['github'] ?? '') : '';
    final changelog = json['changelog'];
    return VersionInfo(
      version: (json['version'] ?? '').toString(),
      releaseDate: (json['release_date'] ?? '').toString(),
      changelog: changelog is List
          ? changelog.map((e) => e.toString()).toList()
          : const <String>[],
      downloadUrl: github.toString(),
    );
  }

  final String version;
  final String releaseDate;
  final List<String> changelog;
  final String downloadUrl;
}

/// 版本检查结果。
@immutable
class VersionCheckResult {
  const VersionCheckResult({
    required this.current,
    required this.latest,
    required this.hasUpdate,
  });

  final String current;
  final VersionInfo latest;
  final bool hasUpdate;
}

/// 当前 App 版本（对齐 pubspec version 2.0.0-beta）。真实接入可从 PackageInfo 读取（阶段4）。
const String kCurrentAppVersion = '2.0.0-beta';

/// 打包在 assets 的 fake 版本清单路径（对齐 legacy public/version.json）。
/// 阶段4 真实化时把「读 asset」换成「HTTP fetch 远端 version.json」，解析/对比逻辑不变。
const String kVersionManifestAsset = 'assets/public/version.json';

/// 兜底 fake 远端（asset 读取失败时用；对齐 version.json）。
const VersionInfo kFallbackLatestVersion = VersionInfo(
  version: '1.0.3',
  releaseDate: '2026-06-13',
  changelog: [
    '支持 U净新洗衣二维码链接',
    '恢复洗衣液和除菌液选项',
    '检查更新改为读取远程版本清单',
  ],
  downloadUrl: 'https://github.com/amamiyakazuki/FlandreSY/releases/latest',
);

/// Fake 版本检查：从打包 asset 读取版本清单并与当前版本对比。
/// 阶段4：把 [_loadManifest] 换成真实 HTTP 请求即可，其余不变。
Future<VersionCheckResult> checkLatestVersionFake() async {
  final latest = await _loadManifest();
  final hasUpdate = compareSemver(latest.version, kCurrentAppVersion) > 0;
  return VersionCheckResult(
    current: kCurrentAppVersion,
    latest: latest,
    hasUpdate: hasUpdate,
  );
}

Future<VersionInfo> _loadManifest() async {
  try {
    final raw = await rootBundle.loadString(kVersionManifestAsset);
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) {
      return VersionInfo.fromJson(json);
    }
  } catch (_) {
    // 解析失败回退兜底（fake 阶段容错；真实阶段应上报错误）。
  }
  return kFallbackLatestVersion;
}

/// 语义版本对比：a>b 返回正，a<b 返回负，相等返回 0。
/// 解析 x.y.z（缺省段按 0；非数字段按 0）。
int compareSemver(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) {
      return pa[i] - pb[i];
    }
  }
  return 0;
}

List<int> _parse(String v) {
  final parts = v.split('.');
  return [
    _seg(parts, 0),
    _seg(parts, 1),
    _seg(parts, 2),
  ];
}

int _seg(List<String> parts, int i) {
  if (i >= parts.length) {
    return 0;
  }
  return int.tryParse(parts[i].trim()) ?? 0;
}
