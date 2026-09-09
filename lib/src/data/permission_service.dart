import 'package:permission_handler/permission_handler.dart';

/// Cross-platform permission state used by the shell and feature entry points.
/// The service deliberately keeps platform details out of widgets.
enum ShuiPermissionKind { camera, bluetooth, notifications }

class ShuiPermissionState {
  const ShuiPermissionState({required this.status});

  final Map<ShuiPermissionKind, PermissionStatus> status;

  PermissionStatus operator [](ShuiPermissionKind kind) => status[kind]!;

  bool get allGranted => status.values.every((value) => value.isGranted);
}

class ShuiPermissionService {
  const ShuiPermissionService();

  Permission _permission(ShuiPermissionKind kind) => switch (kind) {
        ShuiPermissionKind.camera => Permission.camera,
        ShuiPermissionKind.bluetooth => Permission.bluetoothScan,
        ShuiPermissionKind.notifications => Permission.notification,
      };

  Future<ShuiPermissionState> check() async {
    final entries = <ShuiPermissionKind, PermissionStatus>{};
    for (final kind in ShuiPermissionKind.values) {
      entries[kind] = await _permission(kind).status;
    }
    return ShuiPermissionState(status: entries);
  }

  Future<ShuiPermissionState> requestAll() async {
    final entries = <ShuiPermissionKind, PermissionStatus>{};
    for (final kind in ShuiPermissionKind.values) {
      final permission = _permission(kind);
      final current = await permission.status;
      entries[kind] = current.isGranted ? current : await permission.request();
    }
    return ShuiPermissionState(status: entries);
  }

  Future<bool> openSettings() => openAppSettings();
}
