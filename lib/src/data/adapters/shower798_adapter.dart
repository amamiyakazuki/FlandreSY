// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// 慧生活798 shower adapter interface (no visual constants). Separates data source (798 HTTP backend,
// token auth, captcha image endpoint) from state management (emit/notify in shower798/hotwater actions).
// Fake + real both implement this. Method shapes align with legacy Shower798RuntimeAdapter.kt.
// 798 is pure HTTP (no BLE, no signing) — the simplest of the three services.

import '../../runtime/models/account_session.dart';

/// 798 后端错误（HTTP / code!=0 / 未登录）。actions 捕获后 emit failure。
/// [authInvalid] = 服务端明确拒绝了当前 token（401/403 / loadDevices 结构性登录失效），非「从未登录」
/// 也非网络抖动 → action 层据此清 secure + adapter 内存 token + 账号 state 并置 loginRequired（RELOG）。
class Shower798Exception implements Exception {
  const Shower798Exception(this.message, {this.code, this.authInvalid = false});

  final String message;
  final String? code;
  final bool authInvalid;

  @override
  String toString() => 'Shower798Exception($code): $message';
}

/// 798 登录返回的 session（对齐 legacy CachedSession：phone/uid/eid/token）。
class Shower798SessionData {
  const Shower798SessionData({
    required this.phone,
    required this.uid,
    required this.eid,
    required this.token,
  });

  final String phone;
  final String uid;
  final String eid;
  final String token;

  bool get isValid => token.isNotEmpty;
}

/// 图形验证码结果（对齐 legacy CaptchaResult）。
/// base64 = 图片字节 base64（接现有 Image.memory 解码路径）；doubleRandom/timestamp 供 sendSms 复用。
class Shower798CaptchaData {
  const Shower798CaptchaData({
    required this.imageBase64,
    required this.doubleRandom,
    required this.timestamp,
  });

  final String imageBase64;
  final String doubleRandom;
  final String timestamp;
}

/// 慧生活798 洗浴适配器接口（S798）。
///
/// 约定：实现方**只**负责「拿数据 + IO 延迟」，返回结果数据；不碰 runtime state、不 emit。
/// 校验/emit/持久化由 shower798_actions / hotwater_actions 负责。有状态：真实实现登录后
/// 内部持 token（同 UjingHttpAdapter），因此 devices/start/stop 不必透传 session。
abstract class IShower798Adapter {
  /// 请求图形验证码（真实：GET /captcha 图片字节 → base64；fake：fakeCaptchaBase64）。
  Future<Shower798CaptchaData> requestCaptcha();

  /// 发送短信验证码（需上一次 captcha 的 doubleRandom + 用户填的图形码）。
  Future<void> sendSmsCode({
    required String doubleRandom,
    required String imageCaptcha,
    required String phone,
  });

  /// 登录（phone + 短信码）。真实实现内部保存返回的 token 供后续调用。
  Future<Shower798SessionData> login(String phone, String smsCode);

  /// 加载设备列表（/ui/app/master → favos）。
  Future<List<Shower798DeviceUi>> loadDevices();

  /// 添加设备（收藏）。
  Future<void> addDevice(String deviceId);

  /// 删除设备（取消收藏）。
  Future<void> deleteDevice(String deviceId);

  /// 开始洗浴。
  Future<void> startShower(String deviceId);

  /// 结束洗浴。
  Future<void> stopShower(String deviceId);

  /// 设备是否空闲（/ui/app/dev/status → gene.status==99 或 subs[0].status==0）。
  Future<bool> isDeviceIdle(String deviceId);
}
