// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// SharedPreferences-backed SettingsRepository (no visual constants).

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/runtime_status.dart';
import 'settings_repository.dart';

/// 基于 shared_preferences 的设置持久化实现（Android + iOS）。
/// 通过 [SettingsRepository] 接口被 runtime 消费，runtime 不直接依赖此类。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository();

  /// 浴室系统偏好存储 key。值为 [BathSystemPreference.name]（'zhuli' / 'shower798'）。
  static const String _bathSystemKey = 'bath_system_preference';

  /// 「使用模拟后端」开关存储 key（Phase 0）。bool。缺省 false = 真实后端。
  static const String _useSimulatedBackendKey = 'use_simulated_backend';

  @override
  Future<BathSystemPreference> loadBathSystem({
    BathSystemPreference fallback = BathSystemPreference.zhuli,
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
    await prefs.setString(_bathSystemKey, preference.name);
  }

  @override
  Future<bool> loadUseSimulatedBackend({bool fallback = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSimulatedBackendKey) ?? fallback;
  }

  @override
  Future<void> saveUseSimulatedBackend(bool useSimulated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSimulatedBackendKey, useSimulated);
  }
}
