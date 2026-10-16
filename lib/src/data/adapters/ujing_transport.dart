// Ujing HTTP transport seam (no visual constants). Splits "build request + parse JSON + map errors"
// (testable via fixtures) from "real socket IO" (IoUjingTransport, verified on-device by the user).
// UjingHttpAdapter depends on this interface; tests inject a fake transport replaying 抓包 JSON.

/// 一次 Ujing 后端请求的描述（与真实 socket 无关，纯数据）。
/// 字段对齐 legacy UjingApi.java 的 request()（method/path/query/body/appCode/weex/authorization）。
class UjingRequest {
  const UjingRequest({
    required this.method,
    required this.path,
    this.query,
    this.body,
    required this.appCode,
    this.weex,
    this.authToken,
    this.requireVerifiedEnvelope = false,
  });

  /// HTTP 方法：'GET' / 'POST'。
  final String method;

  /// 相对 BASE 的路径（如 `captcha`、`water/createWaterOrder`、`orders/123/detail`）。
  final String path;

  /// query 参数（GET 拼到 URL；null 表示无）。值会被 String 化。
  final Map<String, Object?>? query;

  /// POST body（序列化为 JSON；null 表示无 body）。
  final Map<String, Object?>? body;

  /// legacy `x-app-code`：账号/饮水多为 `ZA`/`CA`，洗衣为 `BA`。
  final String appCode;

  /// legacy `weex-version`：洗衣相关接口需要（如 `1.1.68`）；null 表示不带。
  final String? weex;

  /// 登录 token（对齐 legacy `authorization: Bearer <token>`）。
  /// null = 匿名请求（登录/验证码前）；非空 = 带 Bearer 头。
  /// adapter 对需登录接口先做 requireToken 守卫，再把 token 透传到这里。
  final String? authToken;

  /// 旧记录核对要求明确成功码及非空 data；不改变普通业务响应规则。
  final bool requireVerifiedEnvelope;
}

/// Ujing 传输层接口：发出请求，返回已校验（JSON 数值 code==0）的 `data` map。
///
/// 约定：
/// - 缺失/非数值/非零 code 或非 2xx 均抛 [UjingException]，格式异常不推断鉴权失效。
/// - 返回 `data` 对象；无对象 data 时返回空 map，允许无需数据的确认端点。
/// - 需要业务数据的 adapter 必须检查必要字段，不能将空 map 当有效详情。
abstract class UjingTransport {
  Future<Map<String, dynamic>> send(UjingRequest request);
}
