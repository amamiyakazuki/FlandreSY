// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Runtime permission check (no visual constants). M-REAL 权限检测: request the runtime permissions
// the app actually uses (camera scan, BLE hot-water, location for BLE scan on Android), then — if any
// is permanently denied — fall back to opening the OS app-settings page (aligned with legacy
// openSettings ACTION_APPLICATION_DETAILS_SETTINGS). Returns a human-readable summary for the dialog.

import 'package:permission_handler/permission_handler.dart';

/// 本次要检测/申请的权限集合（对齐 AndroidManifest 已声明的 CAMERA / BLUETOOTH* / ACCESS_FINE_LOCATION，
/// 分别服务：扫码相机、热水 BLE、Android BLE 扫描所需定位）。
const List<Permission> kCheckedPermissions = <Permission>[
  Permission.camera,
  Permission.bluetoothScan,
  Permission.bluetoothConnect,
  Permission.locationWhenInUse,
];

/// 运行权限检测（M-REAL）：申请上述权限；
/// - 全部授予 → 返回「权限已授予」。
/// - 有被永久拒绝 → 打开系统设置（对齐 legacy openSettings）并返回提示。
/// - 其余（部分被拒但可再申请）→ 返回「部分权限未授予」。
/// 返回值用于弹窗/snackbar 展示。可注入 [requester]/[openSettings] 供测试替身。
Future<String> runPermissionCheck({
  Future<Map<Permission, PermissionStatus>> Function()? requester,
  Future<bool> Function()? openSettings,
}) async {
  final statuses = await (requester ?? _defaultRequester)();
  final anyPermanentlyDenied =
      statuses.values.any((s) => s.isPermanentlyDenied);
  final allGranted = statuses.values.every((s) => s.isGranted);

  if (allGranted) {
    return '权限已授予';
  }
  if (anyPermanentlyDenied) {
    await (openSettings ?? openAppSettings)();
    return '部分权限被永久拒绝，已打开系统设置，请手动开启';
  }
  return '部分权限未授予，请在弹窗中允许';
}

Future<Map<Permission, PermissionStatus>> _defaultRequester() =>
    kCheckedPermissions.request();
