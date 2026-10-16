// Pure data model (no visual constants); UI consumers apply design tokens.

import 'package:flutter/foundation.dart';

/// 本地快捷设备类型。对齐 legacy `runtime/ShuiRuntime.kt` 的 `LocalDeviceType`。
/// 本模块 B1 主要使用 [washer] 与 [drinkingWater]（Devices 列表只展示这两类）。
/// [shower798] / [unknown] 先保留枚举，留给后续 798 / 兜底扩展。
enum LocalDeviceType { washer, drinkingWater, shower798, unknown }

/// 本地保存的快捷设备入口（不绑定官方账号，仅本地列表）。
/// 字段 1:1 对齐 legacy `LocalDeviceShortcut`，便于后续接真实 runtime。
@immutable
class LocalDeviceShortcut {
  const LocalDeviceShortcut({
    required this.id,
    required this.customName,
    required this.deviceType,
    this.qrUrl,
    this.cd,
    this.deviceNo,
    this.storeName,
    this.lastStatus,
    this.sortOrder = 0,
    this.statusConfirmed = false,
    this.statusQueryFailed = false,
    this.statusCheckedAt = '',
    Object? incarnation,
  }) : _incarnation = incarnation;

  final Object? _incarnation;
  Object get incarnation => _incarnation ?? this;

  /// 只在当前运行期可信，不从导入或磁盘恢复信任标记。
  final bool statusConfirmed;
  final bool statusQueryFailed;
  final String statusCheckedAt;

  final String id;
  final String customName;
  final LocalDeviceType deviceType;

  /// 洗衣机二维码（含 uuid），用于后续 scanWasher。
  final String? qrUrl;

  /// 饮水设备码（二维码 cd 参数），用于后续创建接水订单。
  final String? cd;

  /// 服务端设备编号（如 070501），可能在刷新后才有。
  final String? deviceNo;

  /// 洗衣门店名（如「学海7舍-5」）。
  final String? storeName;

  /// 最近一次刷新得到的状态文案（如「可下单」「运行中」），未刷新为 null。
  final String? lastStatus;

  final int sortOrder;

  LocalDeviceShortcut copyWith({
    String? customName,
    String? deviceNo,
    String? storeName,
    String? lastStatus,
    int? sortOrder,
    bool? statusConfirmed,
    bool? statusQueryFailed,
    String? statusCheckedAt,
  }) {
    return LocalDeviceShortcut(
      id: id,
      customName: customName ?? this.customName,
      deviceType: deviceType,
      qrUrl: qrUrl,
      cd: cd,
      deviceNo: deviceNo ?? this.deviceNo,
      storeName: storeName ?? this.storeName,
      lastStatus: lastStatus ?? this.lastStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      statusConfirmed: statusConfirmed ?? this.statusConfirmed,
      statusQueryFailed: statusQueryFailed ?? this.statusQueryFailed,
      statusCheckedAt: statusCheckedAt ?? this.statusCheckedAt,
      incarnation: incarnation,
    );
  }
}
