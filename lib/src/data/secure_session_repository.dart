// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Secure credential persistence abstraction (no visual constants). PTOK: the real adapters' auth
// tokens/secrets (UjingHttpAdapter._token, RealZhuliAdapter._session, RealShower798Adapter._token)
// previously lived only in memory — restart forced re-login. This repository persists them encrypted
// (Keystore/Keychain via the platform impl). Kept SEPARATE from AccountSessionRepository (which stores
// non-sensitive identifiers in plain SharedPreferences). Runtime depends only on this interface;
// default InMemory keeps golden/fixture tests deterministic (secure storage has no platform channel
// under `flutter test`).

import 'adapters/hotwater_adapter.dart';

/// 敏感凭证持久化接口（PTOK）。token/secretKey 属机密，与 AccountSessionRepository（明文标识）分离。
///
/// 各 load 返回 null = 无凭证（首启 / 未登录 / 已清）。Ujing/798 是裸 token 字符串；
/// Zhuli 是完整 [ZhuliSessionData]（secretKey+serverAddr 等业务签名/base 关键，7 字段全需）。
abstract class SecureSessionRepository {
  Future<String?> loadUjingToken();
  Future<void> saveUjingToken(String token);
  Future<void> clearUjingToken();

  Future<ZhuliSessionData?> loadZhuliSession();
  Future<void> saveZhuliSession(ZhuliSessionData session);
  Future<void> clearZhuliSession();

  Future<String?> loadShower798Token();
  Future<void> saveShower798Token(String token);
  Future<void> clearShower798Token();
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖（secure storage 在 flutter test 下无 channel）。
class InMemorySecureSessionRepository implements SecureSessionRepository {
  InMemorySecureSessionRepository({
    String? ujingToken,
    ZhuliSessionData? zhuliSession,
    String? shower798Token,
  })  : _ujingToken = ujingToken,
        _zhuliSession = zhuliSession,
        _shower798Token = shower798Token;

  String? _ujingToken;
  ZhuliSessionData? _zhuliSession;
  String? _shower798Token;

  @override
  Future<String?> loadUjingToken() async => _ujingToken;

  @override
  Future<void> saveUjingToken(String token) async => _ujingToken = token;

  @override
  Future<void> clearUjingToken() async => _ujingToken = null;

  @override
  Future<ZhuliSessionData?> loadZhuliSession() async => _zhuliSession;

  @override
  Future<void> saveZhuliSession(ZhuliSessionData session) async =>
      _zhuliSession = session;

  @override
  Future<void> clearZhuliSession() async => _zhuliSession = null;

  @override
  Future<String?> loadShower798Token() async => _shower798Token;

  @override
  Future<void> saveShower798Token(String token) async =>
      _shower798Token = token;

  @override
  Future<void> clearShower798Token() async => _shower798Token = null;
}
