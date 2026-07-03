// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Zhuli BLE (GATT) transport seam (no visual constants — these are protocol byte/UUID constants, not
// UI). Splits "the GATT jump" (scan/connect/write/notify — needs a real BLE plugin + device,
// verified ON-DEVICE by the user) from the signed HTTP layer. RealZhuliAdapter depends on this
// interface; SkeletonBleTransport honestly throws (no fake success). Contract mirrors
// service-interfaces.md §Zhuli BLE Contract + legacy LegacyHotwaterActivity BleDeviceSession.
//
// Z2: awaitNotify is now type-aware (filters by the 3rd byte / index 2, like legacy writeAndWait's
// expectedType) so a real device that emits set_rate/history/crc frames between the ones we want does
// not misfeed the orchestration. hexToBytes/bytesToHex/typeByteOf are pure functions (fixture-tested).

import 'hotwater_adapter.dart';

/// Zhuli BLE 协议契约常量 + 纯函数解析（来自 docs/service-interfaces.md §BLE Contract
/// 与 legacy `LegacyHotwaterActivity`：hexToBytes/bytesToHex/cmdType）。
class ZhuliBleContract {
  const ZhuliBleContract._();

  static const String serviceUuid = '0000ff12-0000-1000-8000-00805f9b34fb';
  static const String writeUuid = '0000ff01-0000-1000-8000-00805f9b34fb';
  static const String readUuid = '0000ff02-0000-1000-8000-00805f9b34fb';
  static const String cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';

  static const Duration scanTimeout = Duration(seconds: 8);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration responseTimeout = Duration(seconds: 6);
  static const int gattRetry = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  /// notify 响应第 3 字节（index 2）→ 类型（对齐 legacy byte-type 判断）。
  static const int typeHandShark = 1; // cmd_hand_shark
  static const List<int> typeHistoryOrder = [2, 67]; // cmd_history_order
  static const List<int> typeStartOrder = [3, 64]; // cmd_start_order
  static const List<int> typeEndConsume = [4, 5, 65]; // cmd_end_consume
  static const int typeSetRate = 16; // cmd_set_rate
  static const int typeErrorCrc = 240; // error_crc

  /// legacy hexToBytes：去空格，两两解析为字节。奇数长度/非法字符抛 [HotwaterException]。
  static List<int> hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '');
    if (clean.length.isOdd) {
      throw HotwaterException('非法 hex（奇数长度）：$hex');
    }
    final out = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      final byte = int.tryParse(clean.substring(i, i + 2), radix: 16);
      if (byte == null) {
        throw HotwaterException('非法 hex：$hex');
      }
      out.add(byte);
    }
    return out;
  }

  /// legacy bytesToHex：每字节两位小写十六进制。
  static String bytesToHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// legacy cmdType 的类型字节：取前 20 字节（40 hex 字符）的 index 2；不足 3 字节返回 null。
  static int? typeByteOf(String hex) {
    final head = hex.length > 40 ? hex.substring(0, 40) : hex;
    final bytes = hexToBytes(head);
    if (bytes.length < 3) {
      return null;
    }
    return bytes[2] & 0xff;
  }

  /// 对一条 notify 帧按期望类型做分类（纯函数，供 awaitNotify 过滤 + fixture 直接验）：
  /// - [ZhuliFrameVerdict.errorCrc]：类型字节 == 240（设备报 CRC 错）。
  /// - [ZhuliFrameVerdict.accept]：类型字节 ∈ expectedTypes。
  /// - [ZhuliFrameVerdict.ignore]：不足 3 字节，或类型不匹配（如穿插的其它帧）。
  static ZhuliFrameVerdict classifyFrame(String hex, List<int> expectedTypes) {
    final type = typeByteOf(hex);
    if (type == null) {
      return ZhuliFrameVerdict.ignore;
    }
    if (type == typeErrorCrc) {
      return ZhuliFrameVerdict.errorCrc;
    }
    if (expectedTypes.contains(type)) {
      return ZhuliFrameVerdict.accept;
    }
    return ZhuliFrameVerdict.ignore;
  }
}

/// notify 帧分类结果（见 [ZhuliBleContract.classifyFrame]）。
enum ZhuliFrameVerdict { accept, errorCrc, ignore }

/// 已连接 BLE 设备句柄（真实实现持 GATT connection；骨架为占位）。
abstract class ZhuliBleConnection {
  /// 写一条 hex 指令到 write characteristic。
  Future<void> writeHex(String hex);

  /// 等待一条**类型匹配**的 notify 响应（返回原始 hex）。
  ///
  /// - 只接受第 3 字节（index 2）∈ [expectedTypes] 的帧（对齐 legacy writeAndWait 的 expectedType）。
  /// - 收到 [ZhuliBleContract.typeErrorCrc]（240）→ 抛 [HotwaterException]（设备报 CRC 错）。
  /// - [ZhuliBleContract.responseTimeout] 内无匹配帧 → 抛 [HotwaterException]。
  Future<String> awaitNotify({required List<int> expectedTypes});

  /// 关闭连接。
  Future<void> close();
}

/// BLE 传输接口：按 ble 名称/mac 扫描 + 连接目标设备，得到可读写的连接。
abstract class BleTransport {
  /// 扫描并连接（对齐 legacy：按 ble_name/ble_mac 或名称含 XN fallback 匹配）。
  Future<ZhuliBleConnection> scanAndConnect({
    required String bleName,
    required String bleMac,
  });
}

/// 骨架实现：不接触真实 BLE，所有方法诚实抛「未实现」。
/// 真机接入：换成 [FlutterBluePlusBleTransport]（见 flutter_blue_plus_ble_transport.dart），
/// 处理权限/扫描/GATT/notify/字节解析。
class SkeletonBleTransport implements BleTransport {
  const SkeletonBleTransport();

  @override
  Future<ZhuliBleConnection> scanAndConnect({
    required String bleName,
    required String bleMac,
  }) async {
    throw const HotwaterException(
      'BLE 未接入：需真实 GATT（真机注入 FlutterBluePlusBleTransport，见 real_zhuli_adapter 注释）',
    );
  }
}
