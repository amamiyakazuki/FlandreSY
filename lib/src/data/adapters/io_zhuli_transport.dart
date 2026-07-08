// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Zhuli signed-HTTP transport (no visual constants). Uses dart:io HttpClient (faithful to legacy
// LegacyHotwaterActivity.ZhuliApi's HttpURLConnection: GET + sign in query + result==true). The
// result-check + data decoding (incl. the base64url-encoded-JSON-string `data` case) lives in the
// pure, fixture-tested [ZhuliUnwrap]; this layer only does the socket IO. THIS IS THE ONLY LAYER THAT
// TOUCHES A REAL SOCKET here, and it is NOT verified by Codex — real network behavior (login/business
// round-trips) must be verified ON-DEVICE by the user. Not enabled by default.

import 'dart:convert';
import 'dart:io';

import 'hotwater_adapter.dart';
import 'zhuli_transport.dart';

/// 真实 Zhuli 签名 HTTP 传输：dart:io [HttpClient] 实现，对齐 legacy `ZhuliApi`。
///
/// - GET + query（含 sign）。签名由 [ZhuliSign] 计算后并入 query。
/// - result 校验 + data 解码（含 base64url 编码 JSON 字符串）由 [ZhuliUnwrap] 负责（可 fixture 测）。
/// - data 为对象/字符串/数组三种取法（getObject/getString/getArray）。
class IoZhuliTransport implements ZhuliTransport {
  IoZhuliTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> getObject(ZhuliRequest request) async {
    final resp = await _send(request);
    return ZhuliUnwrap.asObject(resp, _fail);
  }

  @override
  Future<String> getString(ZhuliRequest request) async {
    final resp = await _send(request);
    return ZhuliUnwrap.asString(resp, _fail);
  }

  @override
  Future<List<dynamic>> getArray(ZhuliRequest request) async {
    final resp = await _send(request);
    return ZhuliUnwrap.asArray(resp, _fail);
  }

  /// unwrap 校验失败信号（api_sign_error 需重登，对齐 legacy）。
  /// err_code == 'api_sign_error' = 服务端判签名/凭证失效 → 标记 authInvalid 触发 RELOG。
  static Never _fail(String message, String code) {
    throw HotwaterException(message,
        code: code, authInvalid: code == 'api_sign_error');
  }

  /// 加 sign → 拼 query → GET → 返回原始响应 Map（result 校验 + data 解码交给 [ZhuliUnwrap]）。
  Future<Map<String, dynamic>> _send(ZhuliRequest request) async {
    final signed = Map<String, Object?>.from(request.params);
    signed['sign'] = ZhuliSign.sign(request.params, request.signKey);

    final base = Uri.parse(request.url);
    final query = <String, String>{};
    signed.forEach((k, v) {
      if (v != null) {
        query[k] = '$v';
      }
    });
    final uri = base.replace(queryParameters: query);

    final HttpClientResponse resp;
    final String text;
    try {
      final req = await _client.getUrl(uri);
      req.headers.set('Accept', 'application/json, text/plain, */*');
      req.headers.contentType = ContentType('application', 'json');
      resp = await req.close();
      text = await resp.transform(utf8.decoder).join();
    } on Exception catch (e) {
      throw HotwaterException('网络请求失败：$e');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // 401/403 = 服务端拒绝当前 session → 标记 authInvalid 触发 RELOG。
      throw HotwaterException('HTTP ${resp.statusCode}: $text',
          code: '${resp.statusCode}',
          authInvalid: resp.statusCode == 401 || resp.statusCode == 403);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw HotwaterException('响应不是合法 JSON：$e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const HotwaterException('响应格式异常（顶层非对象）');
    }
    return decoded;
  }
}
