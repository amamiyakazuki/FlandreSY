// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Local device list persistence abstraction (no visual constants). Same decoupling pattern as
// SettingsRepository / AccountSessionRepository (roadmap §3: keep persistence out of the runtime,
// inject via interface). PDEV: the Devices tab list (state.localDevices) previously lived only in
// memory, seeded from hardcoded demo devices; now it round-trips through this repository.

import 'dart:convert';

import '../runtime/models/local_device.dart';

/// 本地设备列表持久化接口（PDEV）。与 [SettingsRepository]/[AccountSessionRepository] 同构。
///
/// [loadDevices] 返回 null 表示「从未持久化过」（首启 → 空列表起步）；返回 `[]` 表示
/// 「用户曾把设备删空」（恢复空列表，绝不 re-seed）。实现方负责区分二者（key 是否存在）。
abstract class LocalDeviceRepository {
  Future<List<LocalDeviceShortcut>?> loadDevices();
  Future<void> saveDevices(List<LocalDeviceShortcut> devices);
}

/// 本地设备 JSON 编解码（对齐 [LocalDeviceShortcut] 全字段）。抽成静态供 SharedPrefs 实现 + fixture 直用。
class LocalDeviceCodec {
  const LocalDeviceCodec._();

  /// 列表 → JSON 字符串（全字段；deviceType 存枚举名）。
  static String encode(List<LocalDeviceShortcut> devices) {
    return jsonEncode(devices.map(toMap).toList());
  }

  /// JSON 字符串 → 列表。非法/空串返回空列表（调用方另用 key 存在与否区分 null）。
  static List<LocalDeviceShortcut> decode(String json) {
    if (json.isEmpty) {
      return const <LocalDeviceShortcut>[];
    }
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      return const <LocalDeviceShortcut>[];
    }
    final out = <LocalDeviceShortcut>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(fromMap(item.cast<String, dynamic>()));
      }
    }
    return out;
  }

  static Map<String, dynamic> toMap(LocalDeviceShortcut d) {
    return <String, dynamic>{
      'id': d.id,
      'customName': d.customName,
      'deviceType': d.deviceType.name,
      'qrUrl': d.qrUrl,
      'cd': d.cd,
      'deviceNo': d.deviceNo,
      'storeName': d.storeName,
      'lastStatus': d.lastStatus,
      'sortOrder': d.sortOrder,
    };
  }

  static LocalDeviceShortcut fromMap(Map<String, dynamic> m) {
    return LocalDeviceShortcut(
      id: (m['id'] ?? '').toString(),
      customName: (m['customName'] ?? '').toString(),
      deviceType: _typeFromName(m['deviceType']),
      qrUrl: m['qrUrl'] as String?,
      cd: m['cd'] as String?,
      deviceNo: m['deviceNo'] as String?,
      storeName: m['storeName'] as String?,
      lastStatus: m['lastStatus'] as String?,
      sortOrder: m['sortOrder'] is int
          ? m['sortOrder'] as int
          : int.tryParse('${m['sortOrder']}') ?? 0,
    );
  }

  static LocalDeviceType _typeFromName(Object? name) {
    final s = '$name';
    return LocalDeviceType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => LocalDeviceType.unknown,
    );
  }
}

/// 内存实现：默认兜底 + 测试/golden 注入用。无 IO、无平台依赖。
/// 传入非空 [devices] 即模拟「已持久化」（loadDevices 返回该列表，用于 golden 确定性）。
class InMemoryLocalDeviceRepository implements LocalDeviceRepository {
  InMemoryLocalDeviceRepository({List<LocalDeviceShortcut>? devices})
      : _devices = devices;

  List<LocalDeviceShortcut>? _devices;

  @override
  Future<List<LocalDeviceShortcut>?> loadDevices() async => _devices;

  @override
  Future<void> saveDevices(List<LocalDeviceShortcut> devices) async =>
      _devices = List<LocalDeviceShortcut>.of(devices);
}
