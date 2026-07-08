// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Version check (no visual constants). M-REAL: real HTTP fetch of public/version.json (dart:io,
// aligned with io_zhuli_transport style — no plugin), tried against the same ordered URL list as
// legacy checkLatestVersion. Falls back to the bundled asset (checkLatestVersionFake) for offline
// use. compareSemver / VersionInfo.fromJson unchanged.

import 'dart:convert';
import 'dart:io';

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
      // 去 v/V 前缀（对齐 legacy removePrefix("v")/removePrefix("V")）。
      version: _stripV((json['version'] ?? '').toString()),
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

/// 版本检查结果（三态，对齐 legacy VersionCheckResult：失败 / 有新版 / 已最新）。
@immutable
class VersionCheckResult {
  const VersionCheckResult({
    required this.current,
    required this.latest,
    required this.hasUpdate,
    this.error,
  });

  /// 检查失败（网络/解析全失败）。带上当前版本，[latest] 为兜底占位。
  const VersionCheckResult.failure({
    required this.current,
    required String this.error,
  })  : latest = kFallbackLatestVersion,
        hasUpdate = false;

  final String current;
  final VersionInfo latest;
  final bool hasUpdate;

  /// 非 null 表示检查失败（对齐 legacy error 分支）。
  final String? error;
}

/// 当前 App 版本（对齐 pubspec 正式版 2.0.0）。真实接入优先读 PackageInfo，失败再回退此常量。
const String kCurrentAppVersion = '2.0.0';

/// 打包在 assets 的兜底版本清单路径。与仓库根 `public/version.json` 保持同一路径，方便 GitHub Raw /
/// Pages 直接复用同一份文件作为远端版本清单。
const String kVersionManifestAsset = 'public/version.json';

/// 真实更新检查 URL（按优先级，对齐 legacy updateUrls）。首个失败自动试下一个。
const List<String> kVersionManifestUrls = <String>[
  'https://flandresy.pages.dev/version.json',
  'https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/public/version.json',
];

/// 兜底版本清单（asset 读取失败时用）。保持与当前正式版一致，避免 fallback 回到过时版本。
const VersionInfo kFallbackLatestVersion = VersionInfo(
  version: '2.0.0',
  releaseDate: '2026-07-07',
  changelog: [
    'FlandreSY 2.0 正式版发布',
    '真实后端与订单持久化整合',
    'beta 收尾问题修复',
  ],
  downloadUrl: 'https://github.com/amamiyakazuki/FlandreSY/releases/latest',
);

/// 单个 URL 的响应体抓取签名。成功返回 body 字符串；失败（网络/非 2xx）抛异常，外层试下一个。
/// 默认实现走真实 [HttpClient]（dart:io，对齐 io_zhuli_transport 风格，无插件）；测试注入替身。
typedef VersionManifestFetcher = Future<String> Function(
    String url, String userAgent);

/// 真实版本检查（M-REAL）：按序 GET [kVersionManifestUrls]，首个成功即解析对比。
/// 全部失败 → [VersionCheckResult.failure]（对齐 legacy error 分支）。
/// [current] 传真实 PackageInfo.version（main 注入）；缺省用常量兜底。
/// [fetcher] 是测试注入 seam（默认真实 HTTP）。
Future<VersionCheckResult> checkLatestVersion({
  String current = kCurrentAppVersion,
  VersionManifestFetcher? fetcher,
}) async {
  final fetch = fetcher ?? _httpFetch;
  String? lastError;
  for (final url in kVersionManifestUrls) {
    try {
      final body = await fetch(url, 'FlandreSY/$current');
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        continue;
      }
      final latest = VersionInfo.fromJson(json);
      if (latest.version.isEmpty) {
        continue;
      }
      return VersionCheckResult(
        current: current,
        latest: latest,
        hasUpdate: compareSemver(latest.version, current) > 0,
      );
    } catch (e) {
      lastError = e.toString();
    }
  }
  return VersionCheckResult.failure(
    current: current,
    error: lastError ?? '无法连接更新服务器，请稍后再试',
  );
}

/// 默认 HTTP 抓取（dart:io HttpClient）。非 2xx 抛异常 → 外层试下一个 URL。
Future<String> _httpFetch(String url, String userAgent) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    return response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// Fake 版本检查：从打包 asset 读取版本清单并与当前版本对比。离线/测试兜底。
Future<VersionCheckResult> checkLatestVersionFake({
  String current = kCurrentAppVersion,
}) async {
  final latest = await _loadManifest();
  final hasUpdate = compareSemver(latest.version, current) > 0;
  return VersionCheckResult(
    current: current,
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
/// 支持 pre-release：`2.0.0-beta < 2.0.0`，`2.0.0-beta.2 > 2.0.0-beta.1`。
int compareSemver(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa.core[i] != pb.core[i]) {
      return pa.core[i] - pb.core[i];
    }
  }
  if (pa.preRelease.isEmpty && pb.preRelease.isEmpty) {
    return 0;
  }
  if (pa.preRelease.isEmpty) {
    return 1;
  }
  if (pb.preRelease.isEmpty) {
    return -1;
  }
  final len = pa.preRelease.length > pb.preRelease.length
      ? pa.preRelease.length
      : pb.preRelease.length;
  for (var i = 0; i < len; i++) {
    if (i >= pa.preRelease.length) {
      return -1;
    }
    if (i >= pb.preRelease.length) {
      return 1;
    }
    final seg = _compareIdentifier(pa.preRelease[i], pb.preRelease[i]);
    if (seg != 0) {
      return seg;
    }
  }
  return 0;
}

_ParsedVersion _parse(String v) {
  final normalized = _stripV(v).split('+').first.trim();
  final dashIndex = normalized.indexOf('-');
  final corePart =
      dashIndex >= 0 ? normalized.substring(0, dashIndex) : normalized;
  final prePart = dashIndex >= 0 ? normalized.substring(dashIndex + 1) : '';
  final parts = corePart.split('.');
  return _ParsedVersion(
    core: <int>[
      _seg(parts, 0),
      _seg(parts, 1),
      _seg(parts, 2),
    ],
    preRelease: prePart.isEmpty
        ? const <String>[]
        : prePart
            .split('.')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
  );
}

int _seg(List<String> parts, int i) {
  if (i >= parts.length) {
    return 0;
  }
  return int.tryParse(parts[i].trim()) ?? 0;
}

int _compareIdentifier(String a, String b) {
  final aIsNumeric = RegExp(r'^\d+$').hasMatch(a);
  final bIsNumeric = RegExp(r'^\d+$').hasMatch(b);
  if (aIsNumeric && bIsNumeric) {
    return int.parse(a) - int.parse(b);
  }
  if (aIsNumeric != bIsNumeric) {
    return aIsNumeric ? -1 : 1;
  }
  return a.compareTo(b);
}

/// 去掉版本串前缀 v/V（对齐 legacy）。
String _stripV(String v) {
  final t = v.trim();
  if (t.startsWith('v') || t.startsWith('V')) {
    return t.substring(1);
  }
  return t;
}

@immutable
class _ParsedVersion {
  const _ParsedVersion({
    required this.core,
    required this.preRelease,
  });

  final List<int> core;
  final List<String> preRelease;
}
