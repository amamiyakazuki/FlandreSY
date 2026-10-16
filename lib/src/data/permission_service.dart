import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum ShuiPermissionKind { camera, bluetooth }

enum ShuiPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
  unsupported,
  error
}

const iosZhuliUnavailable = 'iOS 住理开关水暂不可用：设备识别尚未适配。登录与历史查询仍可使用。';

class ShuiPermissionResult {
  const ShuiPermissionResult(this.status, this.message);
  final ShuiPermissionStatus status;
  final String message;
  bool get granted => status == ShuiPermissionStatus.granted;
  bool get canRequest =>
      status == ShuiPermissionStatus.denied ||
      status == ShuiPermissionStatus.unknown ||
      status == ShuiPermissionStatus.error;
}

class ShuiPermissionState {
  const ShuiPermissionState({required this.status});
  final Map<ShuiPermissionKind, ShuiPermissionResult> status;
  bool get allGranted {
    if (ShuiPermissionKind.values.any((kind) => !status.containsKey(kind))) {
      return false;
    }
    final applicable = status.values
        .where((r) => r.status != ShuiPermissionStatus.unsupported);
    return applicable.isNotEmpty && applicable.every((r) => r.granted);
  }
}

/// 可注入平台边界；状态读取不申请授权，也不初始化蓝牙无线电。
class PermissionBackend {
  const PermissionBackend();
  TargetPlatform get platform => defaultTargetPlatform;
  Future<int?> androidSdk() =>
      const MethodChannel('flandresy/platform').invokeMethod<int>('androidSdk');
  Future<PermissionStatus> status(Permission permission) => permission.status;
  Future<Map<Permission, PermissionStatus>> request(
          List<Permission> permissions) =>
      permissions.request();
  Future<bool> openSettings() => openAppSettings();
  Future<bool> locationEnabled() async =>
      (await Permission.locationWhenInUse.serviceStatus).isEnabled;
}

class ShuiPermissionService {
  ShuiPermissionService({this.backend = const PermissionBackend()});
  static final instance = ShuiPermissionService();
  final PermissionBackend backend;
  final _requests = <ShuiPermissionKind, Future<ShuiPermissionResult>>{};
  Future<void> _requestTail = Future<void>.value();

  String? get zhuliUnavailableReason =>
      backend.platform == TargetPlatform.iOS ? iosZhuliUnavailable : null;

  Future<List<Permission>?> _permissions(ShuiPermissionKind kind) async {
    if (backend.platform != TargetPlatform.android &&
        backend.platform != TargetPlatform.iOS) {
      return null;
    }
    if (kind == ShuiPermissionKind.camera) return [Permission.camera];
    // C5a 未开放 iOS 住理控制：既不误用 scan/connect，也不申请无用途的蓝牙权限。
    if (backend.platform == TargetPlatform.iOS) return null;
    final sdk = await backend.androidSdk();
    if (sdk == null || sdk < 1) throw StateError('系统版本未知');
    return sdk >= 31
        ? [Permission.bluetoothScan, Permission.bluetoothConnect]
        : [Permission.locationWhenInUse];
  }

  Future<ShuiPermissionState> check() async {
    await _requestTail;
    final result = <ShuiPermissionKind, ShuiPermissionResult>{};
    for (final kind in ShuiPermissionKind.values) {
      result[kind] = await _read(kind);
    }
    return ShuiPermissionState(status: result);
  }

  Future<ShuiPermissionResult> checkKind(ShuiPermissionKind kind) async {
    await _requestTail;
    return _read(kind);
  }

  ShuiPermissionResult _unsupported(ShuiPermissionKind kind) =>
      ShuiPermissionResult(
          ShuiPermissionStatus.unsupported,
          kind == ShuiPermissionKind.bluetooth &&
                  backend.platform == TargetPlatform.iOS
              ? iosZhuliUnavailable
              : '当前平台暂不支持此功能');

  Future<ShuiPermissionResult> _read(ShuiPermissionKind kind) async {
    try {
      final permissions = await _permissions(kind);
      if (permissions == null) return _unsupported(kind);
      final statuses = <Permission, PermissionStatus>{};
      for (final permission in permissions) {
        statuses[permission] = await backend.status(permission);
      }
      return _result(permissions, statuses);
    } catch (_) {
      return const ShuiPermissionResult(
          ShuiPermissionStatus.error, '权限状态读取失败，请重试');
    }
  }

  /// 同一权限合并；不同入口/不同权限也串行，避免多个系统弹窗竞争。
  Future<ShuiPermissionResult> request(ShuiPermissionKind kind) {
    final pending = _requests[kind];
    if (pending != null) return pending;
    final operation = _requestTail.then((_) async {
      try {
        final permissions = await _permissions(kind);
        if (permissions == null) return _unsupported(kind);
        final before = <Permission, PermissionStatus>{};
        for (final permission in permissions) {
          before[permission] = await backend.status(permission);
        }
        final current = _result(permissions, before);
        if (current.granted ||
            current.status == ShuiPermissionStatus.permanentlyDenied ||
            current.status == ShuiPermissionStatus.restricted) {
          return current;
        }
        final needed = permissions
            .where((p) => before[p] != PermissionStatus.granted)
            .toList();
        final response = await backend.request(needed);
        // 缺项不能用旧状态补成成功。
        if (needed.any((p) => !response.containsKey(p))) {
          return const ShuiPermissionResult(
              ShuiPermissionStatus.unknown, '授权结果不完整，请重新检查');
        }
        return _result(permissions, {...before, ...response});
      } catch (_) {
        return const ShuiPermissionResult(
            ShuiPermissionStatus.error, '权限申请未完成，请重试');
      }
    });
    late final Future<ShuiPermissionResult> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_requests[kind], tracked)) _requests.remove(kind);
    });
    _requests[kind] = tracked;
    _requestTail = tracked.then<void>((_) {});
    return tracked;
  }

  ShuiPermissionResult _result(
      List<Permission> expected, Map<Permission, PermissionStatus> values) {
    if (expected.isEmpty || expected.any((p) => !values.containsKey(p))) {
      return const ShuiPermissionResult(
          ShuiPermissionStatus.unknown, '权限状态尚未确定，请重新检查');
    }
    final states = expected.map((p) => values[p]!);
    if (states.every((s) => s.isGranted)) {
      return const ShuiPermissionResult(ShuiPermissionStatus.granted, '权限已授予');
    }
    if (states.any((s) => s.isRestricted)) {
      return const ShuiPermissionResult(
          ShuiPermissionStatus.restricted, '权限受系统限制，请检查设备管理或家长控制设置');
    }
    if (states.any((s) => s.isPermanentlyDenied)) {
      return const ShuiPermissionResult(
          ShuiPermissionStatus.permanentlyDenied, '权限已关闭，请在系统设置中开启');
    }
    if (states.any((s) => s.isDenied)) {
      return const ShuiPermissionResult(
          ShuiPermissionStatus.denied, '尚未获得权限，可点击申请');
    }
    return const ShuiPermissionResult(
        ShuiPermissionStatus.unknown, '权限状态尚未确定，请重新检查');
  }

  Future<String> openSettings() async {
    try {
      return await backend.openSettings()
          ? '已打开系统设置，返回后会重新检查'
          : '未能打开系统设置，请手动进入应用设置';
    } catch (_) {
      return '打开系统设置失败，请重试或手动进入应用设置';
    }
  }

  Future<String?> prepareBluetooth() async {
    if (zhuliUnavailableReason != null) return zhuliUnavailableReason;
    final result = await request(ShuiPermissionKind.bluetooth);
    if (!result.granted) return result.message;
    try {
      if (backend.platform == TargetPlatform.android &&
          (await backend.androidSdk())! <= 30 &&
          !await backend.locationEnabled()) {
        return '定位服务未开启，当前 Android 版本扫描蓝牙需要开启定位服务';
      }
    } catch (_) {
      return '无法确认定位服务状态，请重试';
    }
    return null;
  }
}
