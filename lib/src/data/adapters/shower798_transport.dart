// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// 慧生活798 HTTP transport seam (no visual constants). Splits "build request + parse result JSON /
// captcha bytes" (testable via fixtures) from "real socket IO" (IoShower798Transport, verified
// ON-DEVICE by the user). RealShower798Adapter depends on this interface; tests inject a fake
// transport replaying captured JSON. Token auth (Authorization header), code==0 success check.

/// 一次 798 HTTP 请求。与真实 socket 无关，纯数据。
class Shower798Request {
  const Shower798Request({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.token,
  });

  /// 'GET' / 'POST'。
  final String method;

  /// 相对 BASE 的路径（如 `acc/login`、`ui/app/master`、`dev/start`）。
  final String path;

  /// query 参数（GET 拼到 URL）。
  final Map<String, Object?>? query;

  /// POST JSON body。
  final Map<String, Object?>? body;

  /// 登录 token（对齐 legacy `Authorization: <token>`，无 Bearer 前缀）。null = 匿名。
  final String? token;
}

/// 798 传输接口：发请求，返回已校验（code==0）的响应 JSON（完整 map，含 data）。
///
/// 约定：实现方负责 拼 query/body + Authorization → 真实/伪造 IO → `code!=0` 抛 Shower798Exception。
/// 返回完整解析后的 JSON map（调用方从中取 data.al / data.favos / data.device 等）。
abstract class Shower798Transport {
  Future<Map<String, dynamic>> send(Shower798Request request);

  /// 拉取图片字节并转 base64（captcha 端点，无 JSON 包装）。
  Future<String> getImageBase64(Shower798Request request);
}
