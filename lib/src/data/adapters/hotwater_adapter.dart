// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Zhuli hotwater adapter interface (no visual constants). Separates data source (Zhuli platform +
// signed business HTTP + BLE GATT) from state management (emit/notify in hotwater_actions).
// Fake + real both implement this. Method shapes align with legacy ZhuliApi + HotwaterRuntimeAdapter.
// Zhuli-only: 798 shower (HTTP, not BLE) stays inline in hotwater_actions (separate future adapter).

import '../../runtime/models/hotwater_history.dart';

/// Zhuli 热水后端错误（HTTP / 签名 / BLE）。actions 捕获后 emit failure。
/// [authInvalid] = 服务端明确拒绝了当前 session（401/403 / api_sign_error 等），非「从未登录」
/// 也非网络抖动 → action 层据此清 secure + adapter 内存 session + 账号 state 并置 loginRequired（RELOG）。
class HotwaterException implements Exception {
  const HotwaterException(this.message, {this.code, this.authInvalid = false});

  final String message;
  final String? code;
  final bool authInvalid;

  @override
  String toString() => 'HotwaterException($code): $message';
}

/// 住理登录返回的 session（对齐 legacy `ZhuliSession`）。
/// serverAddr = 业务接口 base；secretKey = 业务签名密钥（session_secret 优先，回退 appsecret）。
class ZhuliSessionData {
  const ZhuliSessionData({
    required this.platformToken,
    required this.userId,
    required this.identityCode,
    required this.serverAddr,
    required this.serverAppId,
    required this.serverId,
    required this.secretKey,
  });

  final String platformToken;
  final String userId;
  final String identityCode;
  final String serverAddr;
  final String serverAppId;
  final String serverId;
  final String secretKey;

  bool get isValid => secretKey.isNotEmpty && userId.isNotEmpty;

  /// PTOK：序列化到 secure storage（7 字段全需——secretKey/serverAddr 是业务签名/base 关键）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'platformToken': platformToken,
        'userId': userId,
        'identityCode': identityCode,
        'serverAddr': serverAddr,
        'serverAppId': serverAppId,
        'serverId': serverId,
        'secretKey': secretKey,
      };

  static ZhuliSessionData fromJson(Map<String, dynamic> json) {
    return ZhuliSessionData(
      platformToken: (json['platformToken'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      identityCode: (json['identityCode'] ?? '').toString(),
      serverAddr: (json['serverAddr'] ?? '').toString(),
      serverAppId: (json['serverAppId'] ?? '').toString(),
      serverId: (json['serverId'] ?? '').toString(),
      secretKey: (json['secretKey'] ?? '').toString(),
    );
  }
}

/// 开/关水结果（对齐 legacy 开关水流程产物）。deviceId + 状态文案 + 可选 orderId/isn。
/// isn：开水握手返回，关水依赖它（真机语义；fake 给占位）。
class HotwaterActionResult {
  const HotwaterActionResult({
    required this.deviceId,
    required this.statusText,
    this.orderId = '',
    this.isn = '',
  });

  final String deviceId;
  final String statusText;
  final String orderId;
  final String isn;
}

/// Zhuli 热水适配器接口（Z1）。
///
/// 约定：实现方**只**负责「拿数据 + 编排 HTTP↔BLE + IO 延迟」，返回结果数据；
/// 不碰 runtime state、不 emit。校验/emit/历史累积由 hotwater_actions 负责。
/// 有状态：真实实现登录后内部持 session + last_isn（同 UjingHttpAdapter 持 token），
/// 因此 start/stop/history 不必透传 session。Fake 忽略 session、纯造数据。
abstract class IHotwaterAdapter {
  /// 住理平台登录（phone + password）。真实实现内部保存返回的 session 供后续签名调用。
  Future<ZhuliSessionData> loginZhuli(String phone, String password);

  /// 开热水（编排：device/get_by_id → BLE 握手 → heart_shark_response 得 isn →
  /// create_order 得 app_bytes → BLE 写 → start_consume_response）。内部保存 isn 供关水用。
  Future<HotwaterActionResult> startHotwater(String deviceId);

  /// 关热水（编排：create_end_consume_cmd → BLE 写 → end_consume_response）。
  /// 依赖开水时保存的 isn（对齐 legacy last_isn）。
  Future<HotwaterActionResult> stopHotwater(String deviceId);

  /// 近 30 天热水消费历史（consume/list_record_by_staffid）。
  Future<List<HotwaterHistoryUi>> loadHistory();
}
