// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
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
}

/// Ujing 传输层接口：发出请求，返回已解析、已校验（code==0）的 `data` JSON map。
///
/// 约定：
/// - 实现方负责真实（或伪造）的 IO + cookie + 头 + `code!=0`/非 2xx → 抛 [UjingException]。
/// - 返回值是响应里的 `data` 对象（已去掉外层 code/message 包装）；`data` 为数组或缺失时返回空 map。
abstract class UjingTransport {
  Future<Map<String, dynamic>> send(UjingRequest request);
}
