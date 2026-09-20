// SharedPreferences-backed SettingsRepository (no visual constants).

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/runtime_status.dart';
import '../runtime/hotwater_state.dart';
import 'dart:convert';
import 'settings_repository.dart';
import 'recoverable_json.dart';

/// 基于 shared_preferences 的设置持久化实现（Android + iOS）。
/// 通过 [SettingsRepository] 接口被 runtime 消费，runtime 不直接依赖此类。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository();

  /// 浴室系统偏好存储 key。值为 [BathSystemPreference.name]。
  static const String _bathSystemKey = 'bath_system_preference';

  /// 「使用模拟后端」开关存储 key（Phase 0）。bool。缺省 false = 真实后端。
  static const String _useSimulatedBackendKey = 'use_simulated_backend';
  static const String _permissionIntroSeenKey = 'permission_intro_seen';
  static const String _hotwaterSessionKey = 'hotwater_session';

  @override
  Future<BathSystemPreference> loadBathSystem({
    BathSystemPreference fallback = BathSystemPreference.none,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_bathSystemKey);
    for (final p in BathSystemPreference.values) {
      if (p.name == stored) {
        return p;
      }
    }
    return fallback;
  }

  @override
  Future<void> saveBathSystem(BathSystemPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_bathSystemKey, preference.name)) {
      throw StateError('偏好保存失败');
    }
  }

  @override
  Future<HotwaterSession?> loadHotwaterSession() async {
    final p = await SharedPreferences.getInstance();
    return readRecoverableJson(p, _hotwaterSessionKey, (raw) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid hotwater session JSON');
      }
      return HotwaterSession.fromJson(decoded);
    });
  }

  @override
  Future<void> saveHotwaterSession(HotwaterSession? session) async {
    final p = await SharedPreferences.getInstance();
    final saved = session == null
        ? await p.remove(_hotwaterSessionKey)
        : await p.setString(_hotwaterSessionKey, jsonEncode(session.toJson()));
    if (!saved) throw StateError('Unable to persist hotwater session');
  }

  @override
  Future<bool> loadUseSimulatedBackend({bool fallback = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSimulatedBackendKey) ?? fallback;
  }

  @override
  Future<void> saveUseSimulatedBackend(bool useSimulated) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_useSimulatedBackendKey, useSimulated)) {
      throw StateError('后端偏好保存失败');
    }
  }

  @override
  Future<bool> loadPermissionIntroSeen({bool fallback = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionIntroSeenKey) ?? fallback;
  }

  @override
  Future<void> savePermissionIntroSeen(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_permissionIntroSeenKey, seen)) {
      throw StateError('权限引导状态保存失败');
    }
  }
}
