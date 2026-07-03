// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Zhuli signed-HTTP transport seam (no visual constants). Splits "build signed request + parse
// result JSON" (testable via fixtures — the MD5 signing is deterministic) from "real socket IO"
// (IoZhuliTransport, verified ON-DEVICE by the user). RealZhuliAdapter depends on this interface;
// tests inject a fake transport replaying captured JSON. Signing algorithm mirrors legacy
// LegacyHotwaterActivity.ZhuliApi.sign exactly.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 一次 Zhuli 签名 HTTP 请求（GET）。与真实 socket 无关，纯数据。
class ZhuliRequest {
  const ZhuliRequest({
    required this.url,
    required this.params,
    required this.signKey,
  });

  /// 完整 URL（platform login 用 PLATFORM_BASE，业务用 session.serverAddr + path）。
  final String url;

  /// 已含 timestamp/noncestr/业务参数，但**不含 sign**（transport 负责算 sign）。
  final Map<String, Object?> params;

  /// 签名密钥：平台接口用 PLATFORM_KEY，业务接口用 session.secretKey。
  final String signKey;
}

/// Zhuli 传输层接口：发签名 GET，返回已 unwrap（result==true）的 data。
///
/// 约定：实现方负责 加 sign → 拼 query → 真实/伪造 IO → `result!=true` 抛 HotwaterException。
/// 返回响应里的 `data`（object）；`data` 为字符串/数组时另有 helper（见 IoZhuliTransport）。
abstract class ZhuliTransport {
  /// 返回 data 为 JSON 对象。
  Future<Map<String, dynamic>> getObject(ZhuliRequest request);

  /// 返回 data 为字符串（如握手/结束 hex 指令）。
  Future<String> getString(ZhuliRequest request);

  /// 返回 data 为数组（如消费历史）。
  Future<List<dynamic>> getArray(ZhuliRequest request);
}

/// Zhuli 签名工具（对齐 legacy ZhuliApi.sign / md5）。抽成静态供 transport + fixture 直接验。
class ZhuliSign {
  const ZhuliSign._();

  /// 签名：按 key 排序、跳过 sign/空值、值去掉引号和空格、`k=v` 用 `&` 连、
  /// 末尾 `&key=<signKey>`，UTF-8 MD5 **大写**十六进制。
  static String sign(Map<String, Object?> params, String signKey) {
    final keys = params.keys.toList()..sort();
    final parts = <String>[];
    for (final k in keys) {
      if (k == 'sign') {
        continue;
      }
      final v = params[k];
      if (v == null) {
        continue;
      }
      final sv = '$v';
      if (sv.isEmpty) {
        continue;
      }
      parts.add('$k=${sv.replaceAll('"', '').replaceAll(' ', '')}');
    }
    final raw = '${parts.join('&')}&key=$signKey';
    return md5.convert(utf8.encode(raw)).toString().toUpperCase();
  }
}

/// Zhuli 响应 unwrap（对齐 legacy ZhuliApi.unwrap / unwrapString / unwrapArray / decodeBase64Url）。
///
/// 关键：Zhuli 的 `data` 常是 **base64url 编码的 JSON 字符串**（登录的 user_info/server_info、
/// 历史数组都走这条），必须先解码再解析——否则拿不到 server_info → secretKey 为空 →
/// 「登录成功但没有拿到项目签名密钥」。抽成静态供 transport + fixture 直接验。
class ZhuliUnwrap {
  const ZhuliUnwrap._();

  /// legacy decodeBase64Url：`-→+`、`_→/`、补 `=` padding 后 base64 解码为 UTF-8。
  /// 非法输入原样返回（对齐 legacy try/catch ignored）。
  static String decodeBase64Url(String text) {
    var normalized = text.replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - normalized.length % 4) % 4;
    normalized += '=' * pad;
    try {
      return utf8.decode(base64.decode(normalized));
    } on Object {
      return text;
    }
  }

  /// `result==true` 校验，返回原始 `data`（任意类型）。失败抛 [signalFailure] 提供的异常。
  static Object? _requireData(
    Map<String, dynamic> resp,
    Never Function(String message, String code) signalFailure,
  ) {
    if (resp['result'] != true) {
      final msg = resp['msg'] ?? resp['err_msg'] ?? '接口返回失败';
      signalFailure('$msg', '${resp['err_code'] ?? ''}');
    }
    return resp['data'];
  }

  /// data 取对象：Map 直接用；String 先 base64url 解码，`{` 开头则解析为对象；否则空对象。
  static Map<String, dynamic> asObject(
    Map<String, dynamic> resp,
    Never Function(String message, String code) signalFailure,
  ) {
    final data = _requireData(resp, signalFailure);
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data == null) {
      return <String, dynamic>{};
    }
    final decoded = decodeBase64Url('$data');
    if (decoded.startsWith('{')) {
      final parsed = jsonDecode(decoded);
      if (parsed is Map) {
        return parsed.cast<String, dynamic>();
      }
    }
    return <String, dynamic>{};
  }

  /// data 取字符串（握手/结束等 hex 指令）：Map 取 `value`；String base64url 解码。
  static String asString(
    Map<String, dynamic> resp,
    Never Function(String message, String code) signalFailure,
  ) {
    final data = _requireData(resp, signalFailure);
    if (data == null) {
      return '';
    }
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      return map.containsKey('value') ? '${map['value']}' : '';
    }
    return decodeBase64Url('$data');
  }

  /// data 取数组（历史）：List 直接用；Map 找 rows/list/records/items/data；
  /// String base64url 解码后按 `[`/`{` 解析。
  static List<dynamic> asArray(
    Map<String, dynamic> resp,
    Never Function(String message, String code) signalFailure,
  ) {
    final data = _requireData(resp, signalFailure);
    if (data is List) {
      return data;
    }
    if (data is Map) {
      return _arrayFromObject(data.cast<String, dynamic>());
    }
    if (data == null) {
      return const <dynamic>[];
    }
    final decoded = decodeBase64Url('$data');
    if (decoded.startsWith('[')) {
      final parsed = jsonDecode(decoded);
      if (parsed is List) {
        return parsed;
      }
    }
    if (decoded.startsWith('{')) {
      final parsed = jsonDecode(decoded);
      if (parsed is Map) {
        return _arrayFromObject(parsed.cast<String, dynamic>());
      }
    }
    return const <dynamic>[];
  }

  static List<dynamic> _arrayFromObject(Map<String, dynamic> obj) {
    for (final key in const ['rows', 'list', 'records', 'items', 'data']) {
      final v = obj[key];
      if (v is List) {
        return v;
      }
    }
    return const <dynamic>[];
  }
}
