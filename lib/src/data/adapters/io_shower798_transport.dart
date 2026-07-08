// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real 慧生活798 HTTP transport (no visual constants). Uses dart:io HttpClient (faithful to legacy
// Shower798RuntimeAdapter.kt's HttpURLConnection: BASE https://i.ilife798.com/api/v1, token in
// Authorization header, code==0 success). THIS IS THE ONLY LAYER THAT TOUCHES A REAL SOCKET here,
// and it is NOT verified by Codex — real network behavior must be verified ON-DEVICE by the user.
// Not enabled by default. captcha image endpoint returns raw bytes -> base64.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'shower798_adapter.dart';
import 'shower798_transport.dart';

/// 真实 798 HTTP 传输：dart:io [HttpClient] 实现，对齐 legacy `Shower798RuntimeAdapter`。
///
/// - BASE：`https://i.ilife798.com/api/v1`
/// - token：登录后放 `Authorization` 头（无 Bearer 前缀，对齐 legacy）。
/// - 校验：非 2xx 或响应 `code!=0` → 抛 [Shower798Exception]（msg/message）。
class IoShower798Transport implements Shower798Transport {
  IoShower798Transport({String baseUrl = kBaseUrl, HttpClient? client})
      : _baseUrl = baseUrl,
        _client = client ?? HttpClient();

  /// 真实后端 base（对齐 legacy BASE_URL）。
  static const String kBaseUrl = 'https://i.ilife798.com/api/v1';

  final String _baseUrl;
  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> send(Shower798Request request) async {
    final uri = _resolve(request);
    final HttpClientResponse resp;
    final String text;
    try {
      final req = await _client.openUrl(request.method, uri);
      req.headers.set('Accept', 'application/json');
      final token = request.token;
      if (token != null && token.isNotEmpty) {
        req.headers.set('Authorization', token);
      }
      final body = request.body;
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.headers.contentType =
            ContentType('application', 'json', charset: 'UTF-8');
        req.add(bytes);
      }
      resp = await req.close();
      text = await resp.transform(utf8.decoder).join();
    } on Exception catch (e) {
      throw Shower798Exception('网络请求失败：$e');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // 401/403 = 服务端拒绝当前 token → 标记 authInvalid 触发 RELOG。
      throw Shower798Exception('HTTP ${resp.statusCode}: $text',
          code: '${resp.statusCode}',
          authInvalid: resp.statusCode == 401 || resp.statusCode == 403);
    }
    if (text.isEmpty) {
      throw const Shower798Exception('服务器返回为空');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw Shower798Exception('响应不是合法 JSON：$e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const Shower798Exception('响应格式异常（顶层非对象）');
    }

    // 对齐 legacy ensureSuccess：code==0 视为成功。
    final code = decoded['code'];
    if (code is num && code != 0) {
      final msg = decoded['msg'] ?? decoded['message'] ?? '请求失败';
      throw Shower798Exception('$msg', code: '$code');
    }
    return decoded;
  }

  @override
  Future<String> getImageBase64(Shower798Request request) async {
    final uri = _resolve(request);
    try {
      final req = await _client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Shower798Exception('验证码 HTTP ${resp.statusCode}',
            code: '${resp.statusCode}');
      }
      final builder = BytesBuilder();
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return base64Encode(builder.toBytes());
    } on Shower798Exception {
      rethrow;
    } on Exception catch (e) {
      throw Shower798Exception('验证码请求失败：$e');
    }
  }

  Uri _resolve(Shower798Request request) {
    final base = Uri.parse('$_baseUrl/${request.path}');
    final query = request.query;
    if (query == null || query.isEmpty) {
      return base;
    }
    final stringQuery = <String, String>{};
    query.forEach((k, v) {
      if (v != null) {
        stringQuery[k] = '$v';
      }
    });
    return base.replace(queryParameters: stringQuery);
  }
}
