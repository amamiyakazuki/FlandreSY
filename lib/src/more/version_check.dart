import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

const String kCurrentAppVersion = '未知';
const String kVersionManifestAsset = 'assets/public/version.json';
const String kVersionManifestUrl =
    'https://raw.githubusercontent.com/amamiyakazuki/FlandreSY/main/assets/public/version.json';
const String kReleasePage =
    'https://github.com/amamiyakazuki/FlandreSY/releases';

@immutable
class InstalledAppInfo {
  const InstalledAppInfo({this.version, this.buildNumber, this.packageName});
  final String? version;
  final int? buildNumber;
  final String? packageName;
  String get displayVersion => version ?? kCurrentAppVersion;

  static Future<InstalledAppInfo> read({
    Future<PackageInfo> Function()? loader,
  }) async {
    try {
      final info = await (loader ?? PackageInfo.fromPlatform)();
      final version = info.version.trim();
      parseAppVersion(version);
      return InstalledAppInfo(
        version: version,
        buildNumber: int.tryParse(info.buildNumber),
        packageName: info.packageName,
      );
    } catch (_) {
      return const InstalledAppInfo();
    }
  }
}

Future<String> currentAppVersion() async =>
    (await InstalledAppInfo.read()).displayVersion;

Version parseAppVersion(String value) {
  // pub_semver also accepts shortened versions; update metadata requires x.y.z.
  if (!RegExp(
          r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$')
      .hasMatch(value)) {
    throw const FormatException('invalid version');
  }
  return Version.parse(value);
}

bool isReleaseUrl(String value, {String? version, bool apk = false}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  const root = '/amamiyakazuki/FlandreSY/releases';
  return apk
      ? version != null &&
          uri.path == '$root/download/v$version/app-release.apk'
      : uri.path == root ||
          (version != null && uri.path == '$root/tag/v$version');
}

@immutable
class VersionInfo {
  const VersionInfo({
    required this.version,
    required this.releaseDate,
    required this.changelog,
    required this.downloadUrl,
    this.buildNumber,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final date = json['release_date'];
    final changes = json['changelog'];
    final downloads = json['downloads'];
    if (version is! String ||
        date is! String ||
        changes is! List ||
        changes.any((v) => v is! String) ||
        downloads is! Map ||
        downloads['github'] is! String) {
      throw const FormatException('invalid manifest fields');
    }
    final parsed = parseAppVersion(version);
    if (parsed.isPreRelease ||
        parsed.build.isNotEmpty ||
        !isReleaseUrl(downloads['github'] as String,
            version: version, apk: true)) {
      throw const FormatException('invalid stable release');
    }
    int? build;
    if (json.containsKey('schemaVersion') || json.containsKey('platforms')) {
      final platforms = json['platforms'];
      if (json['schemaVersion'] is! int ||
          json['schemaVersion'] != 2 ||
          platforms is! Map) {
        throw const FormatException('unsupported manifest schema');
      }
      final android = platforms['android'];
      final ios = platforms['ios'];
      if (android is! Map ||
          android['status'] != 'available' ||
          android['version'] != version ||
          android['downloadUrl'] != downloads['github'] ||
          android['buildNumber'] is! int ||
          android['buildNumber'] <= 0 ||
          android['buildNumber'] > 2100000000 ||
          ios is! Map ||
          ios['status'] != 'unavailable') {
        throw const FormatException('invalid platform release');
      }
      build = android['buildNumber'] as int;
    }
    return VersionInfo(
        version: version,
        releaseDate: date,
        changelog: List<String>.from(changes),
        downloadUrl: downloads['github'] as String,
        buildNumber: build);
  }

  final String version;
  final String releaseDate;
  final List<String> changelog;
  final String downloadUrl;
  final int? buildNumber;
  String get releaseUrl => '$kReleasePage/tag/v$version';
}

enum UpdateState {
  available,
  current,
  newer,
  reviewRelease,
  noChannel,
  unknown,
  failure
}

@immutable
class VersionCheckResult {
  const VersionCheckResult(
      {required this.current,
      required this.state,
      required this.message,
      this.latest,
      this.actionUrl,
      this.actionLabel});
  final String current;
  final VersionInfo? latest;
  final UpdateState state;
  final String message;
  final String? actionUrl;
  final String? actionLabel;
  bool get hasUpdate => state == UpdateState.available;
  bool get failed => state == UpdateState.failure;
  String? get error => failed ? message : null;
}

Future<VersionCheckResult> checkLatestVersion({
  http.Client? client,
  String? currentVersion,
  InstalledAppInfo? installed,
  TargetPlatform? platform,
  Uri? manifestUri,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final app = installed ??
      (currentVersion == null
          ? await InstalledAppInfo.read()
          : InstalledAppInfo(version: currentVersion));
  VersionCheckResult result(UpdateState state, String message,
          {VersionInfo? latest, String? url, String? label}) =>
      VersionCheckResult(
          current: app.displayVersion,
          state: state,
          message: message,
          latest: latest,
          actionUrl: url,
          actionLabel: label);
  final target = platform ?? defaultTargetPlatform;
  if (target != TargetPlatform.android) {
    return result(UpdateState.noChannel,
        target == TargetPlatform.iOS ? '暂未提供 iOS 更新渠道' : '当前平台暂未提供更新渠道',
        url: kReleasePage, label: '查看发布说明');
  }
  try {
    parseAppVersion(app.version ?? '');
  } catch (_) {
    return result(UpdateState.unknown, '无法确认当前版本，请重试读取应用信息');
  }
  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(manifestUri ?? Uri.parse(kVersionManifestUrl))
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return result(
          UpdateState.failure, '版本清单请求失败（${response.statusCode}），请稍后重试。');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not an object');
    }
    final latest = VersionInfo.fromJson(decoded);
    VersionCheckResult review(String message) =>
        result(UpdateState.reviewRelease, message,
            latest: latest, url: latest.releaseUrl, label: '查看发布说明');
    if (app.packageName != 'com.flandresy') {
      return review(app.packageName == 'com.flandresy.debug'
          ? '当前为独立调试版。可查看正式版信息，不能作为本安装的覆盖更新。'
          : '无法确认安装包身份，请查看发布说明；未提供直接覆盖下载。');
    }
    final comparison = compareSemver(latest.version, app.version!);
    if (comparison < 0) {
      return result(UpdateState.newer, '当前版本高于已发布稳定版，无需降级。', latest: latest);
    }
    final currentBuild = app.buildNumber;
    if (currentBuild == null ||
        currentBuild <= 0 ||
        latest.buildNumber == null) {
      return review('发布版本 ${latest.version}；缺少构建兼容信息，请查看说明确认升级方式，不要卸载旧应用。');
    }
    if (latest.buildNumber! < currentBuild) {
      return review('发布包的内部版本码低于当前安装，不能覆盖更新。请查看说明，不要卸载旧应用。');
    }
    if (comparison == 0 && latest.buildNumber == currentBuild) {
      return result(UpdateState.current, '当前版本 ${app.version} 暂无可用更新。',
          latest: latest);
    }
    if (latest.buildNumber == currentBuild) {
      return review('发布信息与安装版本不一致，暂不提供覆盖下载。');
    }
    return result(UpdateState.available, '发现可用更新。覆盖安装前请保留本地记录，勿卸载旧应用。',
        latest: latest, url: latest.downloadUrl, label: '打开下载链接');
  } on FormatException {
    return result(UpdateState.failure, '版本清单格式无效，请稍后重试。');
  } catch (_) {
    return result(UpdateState.failure, '检查更新失败，请检查网络后重试。');
  } finally {
    if (ownedClient) httpClient.close();
  }
}

int compareSemver(String a, String b) =>
    parseAppVersion(a).compareTo(parseAppVersion(b));
