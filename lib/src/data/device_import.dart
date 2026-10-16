import 'dart:convert';

import '../runtime/models/local_device.dart';
import '../runtime/scan_routing.dart';

/// 新导入严格验证；旧库仍由宽容的 LocalDeviceCodec 读取。
class DeviceImport {
  static List<LocalDeviceShortcut> parse(String raw) {
    if (raw.trim().isEmpty) throw const FormatException('剪贴板为空');
    dynamic value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('不是有效的 JSON');
    }
    if (value is! List || value.isEmpty) {
      throw const FormatException('需要非空设备数组；不能通过空数组清空列表');
    }
    final ids = <String>{};
    final codes = <String>{};
    final result = <LocalDeviceShortcut>[];
    for (var i = 0; i < value.length; i++) {
      Never invalid(String message) =>
          throw FormatException('第 ${i + 1} 条：$message');
      final item = value[i];
      if (item is! Map) invalid('设备必须是对象');
      final id = item['id'];
      if (id is! String || id.trim().isEmpty) invalid('id 必须是非空字符串');
      if (!ids.add(id.trim())) invalid('id 重复');
      final type = switch (item['deviceType']) {
        'washer' => LocalDeviceType.washer,
        'drinkingWater' => LocalDeviceType.drinkingWater,
        _ => null,
      };
      if (type == null) invalid('仅支持 washer / drinkingWater 类型');
      if (item['customName'] is! String) invalid('customName 必须是字符串');
      for (final key in [
        'qrUrl',
        'cd',
        'deviceNo',
        'storeName',
        'lastStatus'
      ]) {
        if (item[key] != null && item[key] is! String) {
          invalid('$key 必须是字符串或 null');
        }
      }
      final qr = (item['qrUrl'] as String?)?.trim();
      final cd = (item['cd'] as String?)?.trim();
      if (type == LocalDeviceType.washer && !validWasherQr(qr)) {
        invalid('qrUrl 不受支持或缺少设备标识');
      }
      if (type == LocalDeviceType.drinkingWater && (cd == null || cd.isEmpty)) {
        invalid('cd 不能为空');
      }
      if (!codes
          .add('${type.name}:${type == LocalDeviceType.washer ? qr : cd}')) {
        invalid('设备码重复');
      }
      final rawOrder = item.containsKey('sortOrder') ? item['sortOrder'] : 0;
      final order = rawOrder is int
          ? rawOrder
          : rawOrder is String
              ? int.tryParse(rawOrder)
              : null;
      if (order == null || order < 0) invalid('sortOrder 必须是非负整数');
      result.add(LocalDeviceShortcut(
        id: id.trim(),
        customName: item['customName'] as String,
        deviceType: type,
        qrUrl: qr,
        cd: cd,
        deviceNo: item['deviceNo'] as String?,
        storeName: item['storeName'] as String?,
        lastStatus: item['lastStatus'] as String?,
        sortOrder: order,
      ));
    }
    return List.unmodifiable(result);
  }

  static bool validWasherQr(String? qr) {
    if (qr == null) return false;
    try {
      if (classifyScanRouting(qr) is! ScanRoutingWasher) return false;
      final uri = Uri.tryParse(qr);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        return false;
      }
      // 不猜测路径或展示名是设备标识；仅接受现有二维码携带的标识参数。
      return ['uuid', 'cd']
          .any((key) => (uri.queryParameters[key]?.trim() ?? '').isNotEmpty);
    } catch (_) {
      return false;
    }
  }
}

class DeviceChangeResult {
  const DeviceChangeResult(this.success, this.message);
  final bool success;
  final String message;
}

class DeviceImportPreview {
  const DeviceImportPreview(this.devices, this.revision, this.previousCount);
  final List<LocalDeviceShortcut> devices;
  final int revision;
  final int previousCount;
}
