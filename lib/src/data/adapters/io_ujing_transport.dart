// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Ujing HTTP transport (no visual constants). Uses dart:io HttpClient (faithful to legacy
// UjingApi.java's HttpURLConnection: BASE + cookie jar + appCode/weex/brand/model headers + Bearer).
// THIS IS THE ONLY LAYER THAT TOUCHES A REAL SOCKET, and it is NOT verified by Codex — real network
// behavior (login/scan/order round-trips) must be verified ON-DEVICE by the user. Used in the default
// (real) mode; the simulate-backend toggle (or --dart-define=SIMULATE_BACKEND=true) swaps in Fake instead.

import 'dart:convert';
import 'dart:io';

import 'ujing_adapter.dart';
import 'ujing_transport.dart';

/// 真实 Ujing HTTP 传输：dart:io [HttpClient] 实现，对齐 legacy `UjingApi.java`。
///
/// - BASE：`https://phoenix.ujing.online/api/v1/`
/// - cookie：登录后服务器下发的 Set-Cookie 记入内存 jar，后续请求带上（对齐 legacy cookies map）。
/// - 固定头：`x-mobile-brand`/`x-mobile-model`/`x-app-version=2.4.14`/`user-agent=okhttp/4.3.1`。
/// - 逐请求头：`x-app-code`（appCode）、`weex-version`（weex，可选）、`authorization: Bearer <token>`（可选）。
/// - 校验：非 2xx 或响应 `code!=0` → 抛 [UjingException]（message/code 来自响应）。
class IoUjingTransport implements UjingTransport {
  IoUjingTransport({String baseUrl = kUjingBaseUrl, HttpClient? client})
      : _baseUrl = baseUrl,
        _client = client ?? HttpClient();

  /// 真实后端 base（对齐 legacy UjingApi.BASE）。
  static const String kUjingBaseUrl = 'https://phoenix.ujing.online/api/v1/';

  // legacy 固定机型/版本头（UjingApi.APP_VERSION/MODEL/BRAND）。
  static const String _appVersion = '2.4.14';
  static const String _model = 'HBN-AL00';
  static const String _brand = 'HUAWEI';
  static const String _userAgent = 'okhttp/4.3.1';

  final String _baseUrl;
  final HttpClient _client;

  /// 内存 cookie jar（name -> value），对齐 legacy UjingApi.cookies（本轮不落盘，重启即失）。
  final Map<String, String> _cookies = <String, String>{};

  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    final uri = _resolve(request);
    final HttpClientRequest req;
    try {
      req = await _client.openUrl(request.method, uri);
    } on Exception catch (e) {
      throw UjingException('网络请求失败：$e');
    }

    req.headers
      ..set('x-mobile-brand', _brand)
      ..set('x-mobile-id', '')
      ..set('x-app-code', request.appCode)
      ..set('x-app-version', _appVersion)
      ..set('x-mobile-model', _model)
      ..set('accept-encoding', 'identity')
      ..set('user-agent', _userAgent);
    final weex = request.weex;
    if (weex != null && weex.isNotEmpty) {
      req.headers.set('weex-version', weex);
    }
    final token = request.authToken;
    if (token != null && token.isNotEmpty) {
      req.headers.set('authorization', 'Bearer $token');
    }
    final cookie = _cookieHeader();
    if (cookie.isNotEmpty) {
      req.headers.set('cookie', cookie);
    }

    final body = request.body;
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      req.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      req.headers.set('content-length', bytes.length.toString());
      req.add(bytes);
    }

    final HttpClientResponse resp;
    final String text;
    try {
      resp = await req.close();
      text = await resp.transform(utf8.decoder).join();
    } on Exception catch (e) {
      throw UjingException('网络响应读取失败：$e');
    }
    _rememberCookies(resp);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // 401/403 = 服务端拒绝当前凭证 → 标记 authInvalid 触发 RELOG 清凭证+重登。
      throw UjingException('HTTP ${resp.statusCode}: $text',
          code: '${resp.statusCode}',
          authInvalid: resp.statusCode == 401 || resp.statusCode == 403);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw UjingException('响应不是合法 JSON：$e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UjingException('响应格式异常（顶层非对象）');
    }

    final code = decoded['code'];
    if (code is num && code != 0) {
      final message = decoded['message'];
      throw UjingException(
        message is String && message.isNotEmpty ? message : '接口返回错误 code=$code',
        code: '$code',
      );
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    // data 为数组/缺失时返回空 map（调用方按需从中取字段，缺失即默认值）。
    return <String, dynamic>{};
  }

  Uri _resolve(UjingRequest request) {
    final base = Uri.parse(_baseUrl + request.path);
    final query = request.query;
    if (query == null || query.isEmpty) {
      return base;
    }
    final stringQuery = <String, String>{};
    query.forEach((key, value) {
      if (value != null) {
        stringQuery[key] = '$value';
      }
    });
    return base.replace(queryParameters: stringQuery);
  }

  void _rememberCookies(HttpClientResponse resp) {
    for (final cookie in resp.cookies) {
      if (cookie.name.isNotEmpty) {
        _cookies[cookie.name] = cookie.value;
      }
    }
  }

  String _cookieHeader() {
    if (_cookies.isEmpty) {
      return '';
    }
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}
