// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// flutter_secure_storage-backed SecureSessionRepository (no visual constants). Stores auth tokens /
// secrets encrypted via Android Keystore / iOS Keychain. THIS IS THE ONLY LAYER THAT TOUCHES REAL
// secure storage, and it is NOT verified by Codex (no device / no platform channel under test) — real
// Keystore/Keychain behavior must be verified ON-DEVICE by the user. Injected in the default (real)
// mode; in simulate-backend mode the runtime uses InMemorySecureSessionRepository (no token) instead.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'adapters/hotwater_adapter.dart';
import 'secure_session_repository.dart';

/// 基于 flutter_secure_storage 的敏感凭证持久化实现（Android Keystore / iOS Keychain）。
class FlutterSecureSessionRepository implements SecureSessionRepository {
  FlutterSecureSessionRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _ujingTokenKey = 'secure_ujing_token';
  static const String _zhuliSessionKey = 'secure_zhuli_session_json';
  static const String _s798TokenKey = 'secure_shower798_token';

  @override
  Future<String?> loadUjingToken() => _storage.read(key: _ujingTokenKey);

  @override
  Future<void> saveUjingToken(String token) =>
      _storage.write(key: _ujingTokenKey, value: token);

  @override
  Future<void> clearUjingToken() => _storage.delete(key: _ujingTokenKey);

  @override
  Future<ZhuliSessionData?> loadZhuliSession() async {
    final json = await _storage.read(key: _zhuliSessionKey);
    if (json == null || json.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      return null;
    }
    return ZhuliSessionData.fromJson(decoded.cast<String, dynamic>());
  }

  @override
  Future<void> saveZhuliSession(ZhuliSessionData session) =>
      _storage.write(key: _zhuliSessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> clearZhuliSession() => _storage.delete(key: _zhuliSessionKey);

  @override
  Future<String?> loadShower798Token() => _storage.read(key: _s798TokenKey);

  @override
  Future<void> saveShower798Token(String token) =>
      _storage.write(key: _s798TokenKey, value: token);

  @override
  Future<void> clearShower798Token() => _storage.delete(key: _s798TokenKey);
}
