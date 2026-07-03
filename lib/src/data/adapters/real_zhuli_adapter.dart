// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Zhuli hotwater adapter (no visual constants). Orchestrates the signed-HTTP <-> BLE interleave
// for login / start / stop / history, faithful to legacy ZhuliApi + HotwaterRuntimeAdapter +
// service-interfaces.md §Zhuli. HTTP (build signed request + parse) is testable via fixtures through
// the injected ZhuliTransport; the BLE GATT steps go through BleTransport (SkeletonBleTransport throws
// until the user wires a real plugin on-device). NOT enabled by default (main line = FakeHotwaterAdapter).
//
// 真机接入（用户）：
// 1. 选 BLE 插件（如 flutter_blue_plus），实现 BleTransport（scanAndConnect / writeHex / awaitNotify），
//    用 ZhuliBleContract 的 UUID/超时/byte 类型解析 notify（第 3 字节判类型）。
// 2. Android/iOS 声明 BLE + 定位权限；运行时请求。
// 3. 注入：main() 在开关下 RealZhuliAdapter(transport: IoZhuliTransport(), ble: <real ble>)。
// 4. 用真实住理账号 + 真实设备走开水/关水。

import 'dart:convert';

import '../../runtime/models/hotwater_history.dart';
import 'ble_transport.dart';
import 'hotwater_adapter.dart';
import 'zhuli_transport.dart';

/// 真实 Zhuli 热水适配器（Z1）。有状态：登录后持 session；开水后持 last_isn（对齐 legacy）。
/// nonceGen/timestampGen 可注入，测试固定 → 签名可确定性验证（默认真实随机/时钟）。
class RealZhuliAdapter implements IHotwaterAdapter {
  RealZhuliAdapter({
    required ZhuliTransport transport,
    BleTransport? ble,
    String Function()? nonce,
    String Function()? timestamp,
    ZhuliSessionData? session,
  })  : _transport = transport,
        _ble = ble ?? const SkeletonBleTransport(),
        _nonce = nonce ?? _defaultNonce,
        _timestamp = timestamp ?? _defaultTimestamp,
        _session = session;

  static const String kPlatformBase = 'https://pm.whxinna.com';
  static const String kPlatformKey = '6d5dbb85b949447a95ff8fda9a9b759b';
  static const String kFallbackServerAddr = 'https://f5-zhuli.whxinna.com';

  final ZhuliTransport _transport;
  final BleTransport _ble;
  final String Function() _nonce;
  final String Function() _timestamp;

  ZhuliSessionData? _session;

  /// 开水握手保存的 isn（对齐 legacy last_isn）；关水依赖它。
  String _lastIsn = '';

  /// RELOG：服务端拒绝当前 session 时由 action 层调用，清内存凭证（配合 secure.clear + 账号 state 清空）。
  void invalidateAuth() {
    _session = null;
    _lastIsn = '';
  }

  ZhuliSessionData _requireSession() {
    final s = _session;
    if (s == null || !s.isValid) {
      throw const HotwaterException('请先登录住理生活');
    }
    return s;
  }

  // ===== 登录 =====

  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async {
    // 平台登录：PLATFORM_KEY 签名（对齐 legacy ZhuliApi.login）。
    final params = <String, Object?>{
      'appVersion': '3.11.51',
      'systemType': 'Android',
      'systemVersion': '',
      'deviceModel': 'Flutter',
      'deviceToken': '',
      'pwd': password,
      'phone': phone,
      'code': '',
      'base64_user_extends': _base64Url('{"isAlipayAppExist":false}'),
      'timestamp': _timestamp(),
      'noncestr': _nonce(),
    };
    final data = await _transport.getObject(ZhuliRequest(
      url: '$kPlatformBase/webapi/users/login',
      params: params,
      signKey: kPlatformKey,
    ));
    final user = _obj(data, 'user_info');
    final server = _obj(data, 'server_info');
    final sessionSecret = _str(server, 'session_secret');
    final secretKey =
        sessionSecret.isNotEmpty ? sessionSecret : _str(server, 'appsecret');
    if (secretKey.isEmpty) {
      throw const HotwaterException('登录成功但没有拿到项目签名密钥');
    }
    var serverAddr = _str(server, 'server_addr');
    if (serverAddr.isEmpty) {
      serverAddr = kFallbackServerAddr;
    }
    final session = ZhuliSessionData(
      platformToken: _str(data, 'platform_token'),
      userId: _str(user, 'id'),
      identityCode: _str(user, 'identity_code'),
      serverAddr: serverAddr,
      serverAppId: _str(server, 'server_appid'),
      serverId: _str(server, 'server_id'),
      secretKey: secretKey,
    );
    _session = session;
    return session;
  }

  // ===== 开水（HTTP↔BLE 交织，对齐 legacy startHotwater 生命周期）=====

  @override
  Future<HotwaterActionResult> startHotwater(String deviceId) async {
    final s = _requireSession();
    if (deviceId.isEmpty) {
      throw const HotwaterException('设备码为空');
    }

    // 1. device/get_by_id → ble 名称/mac/类型。
    final device = await _business(s, 'device/get_by_id', {'id': deviceId});
    final bleName = _str(device, 'ble_name');
    final bleMac = _str(device, 'ble_mac');
    final deviceType = _str(device, 'device_type');
    // 对齐 legacy：device_type ∈ {3,5} 的设备跳过 set_rate / history_order 两个可选步。
    final skipOptional = deviceType == '3' || deviceType == '5';

    // 2. 扫描 + 连接 BLE（骨架抛未实现；真机为真实 GATT）。
    final conn = await _ble.scanAndConnect(bleName: bleName, bleMac: bleMac);
    try {
      // 3. 取握手 hex → BLE 写 → 等 cmd_hand_shark（type 1）。
      final handshakeHex =
          await _businessString(s, 'device/ble/create_hand_shake_cmd', {
        'device_id': deviceId,
      });
      await conn.writeHex(handshakeHex);
      final handshakeResp = await conn.awaitNotify(
        expectedTypes: const [ZhuliBleContract.typeHandShark],
      );

      // 4. heart_shark_response → isn + 可选 ratecmd + result。
      final heart = await _business(s, 'device/ble/heart_shark_response', {
        'device_id': deviceId,
        'hex': handshakeResp,
      });
      final isn = _str(heart, 'isn');
      if (isn.isEmpty) {
        throw const HotwaterException('握手成功但没有拿到 isn');
      }
      _lastIsn = isn;
      final rateCmd = _str(heart, 'ratecmd');
      final handshakeResult = _str(heart, 'result');

      // 5.（可选）set_rate：有 ratecmd 且设备类型非 3/5 → 写费率，等 cmd_set_rate（type 16）。
      if (!skipOptional && rateCmd.isNotEmpty) {
        await conn.writeHex(rateCmd);
        await conn.awaitNotify(
          expectedTypes: const [ZhuliBleContract.typeSetRate],
        );
      }

      // 6.（可选）history_order：设备类型非 3/5 且握手 result≠3 → 同步旧订单。
      if (!skipOptional && handshakeResult != '3') {
        final historyHex =
            await _businessString(s, 'device/ble/create_history_order_cmd', {
          'device_id': deviceId,
          'isn': isn,
        });
        await conn.writeHex(historyHex);
        final historyResp = await conn.awaitNotify(
          expectedTypes: ZhuliBleContract.typeHistoryOrder,
        );
        await _business(s, 'consume/ble/end_consume_response', {
          'device_id': deviceId,
          'hex': historyResp,
        });
      }

      // 7. create_order → app_bytes + order_id。
      final order = await _business(s, 'consume/create_order', {
        'isn': isn,
        'device_id': deviceId,
        'net_type': 4,
        'staff_id': s.userId,
        'money': 0,
        'consume_value': 0,
      });
      final appBytes = _str(order, 'app_bytes');
      final orderId = _str(order, 'order_id');

      // 8. BLE 写 app_bytes → 等 cmd_start_order（type 3/64）→ start_consume_response 确认。
      await conn.writeHex(appBytes);
      final startResp = await conn.awaitNotify(
        expectedTypes: ZhuliBleContract.typeStartOrder,
      );
      await _business(s, 'consume/ble/start_consume_response', {
        'device_id': deviceId,
        'order_id': orderId,
        'hex': startResp,
      });

      return HotwaterActionResult(
        deviceId: deviceId,
        statusText: '热水启动完成，供应中',
        orderId: orderId,
        isn: isn,
      );
    } finally {
      await conn.close();
    }
  }

  // ===== 关水（对齐 legacy stopHotwater）=====

  @override
  Future<HotwaterActionResult> stopHotwater(String deviceId) async {
    final s = _requireSession();
    if (_lastIsn.isEmpty) {
      throw const HotwaterException('只能关闭本 App 本次打开的热水（缺少 isn）');
    }
    final device = await _business(s, 'device/get_by_id', {'id': deviceId});
    final conn = await _ble.scanAndConnect(
      bleName: _str(device, 'ble_name'),
      bleMac: _str(device, 'ble_mac'),
    );
    try {
      final endHex =
          await _businessString(s, 'consume/ble/create_end_consume_cmd', {
        'device_id': deviceId,
        'isn': _lastIsn,
      });
      await conn.writeHex(endHex);
      final endResp = await conn.awaitNotify(
        expectedTypes: ZhuliBleContract.typeEndConsume,
      );
      await _business(s, 'consume/ble/end_consume_response', {
        'device_id': deviceId,
        'hex': endResp,
      });
      _lastIsn = '';
      return HotwaterActionResult(deviceId: deviceId, statusText: '热水已关闭');
    } finally {
      await conn.close();
    }
  }

  // ===== 历史 =====

  @override
  Future<List<HotwaterHistoryUi>> loadHistory() async {
    final s = _requireSession();
    final rows = await _businessArray(s, 'consume/list_record_by_staffid', {
      'staff_id': s.userId,
      'start': '',
      'end': '',
    });
    final history = <HotwaterHistoryUi>[];
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final m = row.cast<String, dynamic>();
      history.add(HotwaterHistoryUi(
        time: _str(m, 'create_time', fallback: _str(m, 'time')),
        deviceId: _str(m, 'device_id'),
        amount: '¥${_str(m, 'money', fallback: '0')}',
        status: _str(m, 'status_text', fallback: '已结束'),
        orderId: _str(m, 'order_id', fallback: _str(m, 'id')),
      ));
    }
    return history;
  }

  // ===== 业务请求 helpers（signed，对齐 legacy businessParams + addBusinessSign）=====

  Map<String, Object?> _businessParams(ZhuliSessionData s) {
    final p = <String, Object?>{
      'timestamp': _timestamp(),
      'noncestr': _nonce(),
      'user_id': s.userId,
    };
    if (s.identityCode.isNotEmpty) {
      p['identitycode'] = s.identityCode;
    }
    if (s.serverAppId.isNotEmpty) {
      p['pid'] = s.serverAppId;
    }
    if (s.serverId.isNotEmpty) {
      p['appid'] = s.serverId;
    }
    return p;
  }

  ZhuliRequest _businessRequest(
    ZhuliSessionData s,
    String path,
    Map<String, Object?> extra,
  ) {
    final params = _businessParams(s)..addAll(extra);
    return ZhuliRequest(
      url: '${s.serverAddr}/webapi/v1/$path',
      params: params,
      signKey: s.secretKey,
    );
  }

  Future<Map<String, dynamic>> _business(
    ZhuliSessionData s,
    String path,
    Map<String, Object?> extra,
  ) =>
      _transport.getObject(_businessRequest(s, path, extra));

  Future<String> _businessString(
    ZhuliSessionData s,
    String path,
    Map<String, Object?> extra,
  ) =>
      _transport.getString(_businessRequest(s, path, extra));

  Future<List<dynamic>> _businessArray(
    ZhuliSessionData s,
    String path,
    Map<String, Object?> extra,
  ) =>
      _transport.getArray(_businessRequest(s, path, extra));

  // ===== 小工具 =====

  static String _defaultTimestamp() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

  static String _defaultNonce() {
    // 非签名安全用途（对齐 legacy nonce）；避免 Math.random 依赖，用时钟派生。
    final seed = DateTime.now().microsecondsSinceEpoch;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final sb = StringBuffer();
    var x = seed;
    for (var i = 0; i < 32; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      sb.write(chars[x % chars.length]);
    }
    return sb.toString();
  }

  static String _base64Url(String text) {
    // 对齐 legacy base64Url：标准 base64（NO_WRAP）后 +→- /→_。
    return base64.encode(utf8.encode(text)).replaceAll('+', '-').replaceAll('/', '_');
  }

  static Map<String, dynamic> _obj(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is Map) {
      return v.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  static String _str(Map<String, dynamic> map, String key,
      {String fallback = ''}) {
    final v = map[key];
    if (v == null) {
      return fallback;
    }
    if (v is String) {
      return v.isEmpty ? fallback : v;
    }
    return '$v';
  }
}
