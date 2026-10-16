// Persistence abstraction (no visual constants). Decouples runtime from storage IO
// (roadmap §3/§4: keep persistence out of the runtime; inject via interface).

import '../runtime/runtime_status.dart';
import '../runtime/hotwater_state.dart';

/// 设置持久化接口（P1 架构准备）。
///
/// 目的：把「存哪里、怎么存」与 runtime 解耦。runtime 只依赖此接口，
/// 生产注入 [SharedPrefsSettingsRepository]，测试注入 [InMemorySettingsRepository]，
/// golden 因此保持确定性（不触平台 channel）。
///
/// P1 只落地浴室系统偏好；后续登录 session / 设备列表持久化可在此扩展同类方法，
/// 或新增同构 repository（DeviceRepository / SessionRepository）。
abstract class SettingsRepository {
  /// 读取已保存的浴室系统偏好；无记录时返回 [fallback]（首启默认）。
  Future<BathSystemPreference> loadBathSystem({
    BathSystemPreference fallback = BathSystemPreference.none,
  });

  /// 持久化浴室系统偏好。
  Future<void> saveBathSystem(BathSystemPreference preference);
  Future<HotwaterSession?> loadHotwaterSession();
  Future<void> saveHotwaterSession(HotwaterSession? session);

  Future<bool> loadPermissionIntroSeen({bool fallback = false});

  Future<void> savePermissionIntroSeen(bool seen);
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({
    BathSystemPreference? initial,
  }) : _bathSystem = initial;

  BathSystemPreference? _bathSystem;
  bool? _permissionIntroSeen;

  @override
  Future<BathSystemPreference> loadBathSystem({
    BathSystemPreference fallback = BathSystemPreference.none,
  }) async {
    return _bathSystem ?? fallback;
  }

  @override
  Future<void> saveBathSystem(BathSystemPreference preference) async {
    _bathSystem = preference;
  }

  HotwaterSession? _hotwaterSession;
  @override
  Future<HotwaterSession?> loadHotwaterSession() async => _hotwaterSession;
  @override
  Future<void> saveHotwaterSession(HotwaterSession? session) async {
    _hotwaterSession = session;
  }

  @override
  Future<bool> loadPermissionIntroSeen({bool fallback = false}) async =>
      _permissionIntroSeen ?? fallback;

  @override
  Future<void> savePermissionIntroSeen(bool seen) async {
    _permissionIntroSeen = seen;
  }
}
