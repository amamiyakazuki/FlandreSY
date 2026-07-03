// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Persistence abstraction (no visual constants). Decouples runtime from storage IO
// (roadmap §3/§4: keep persistence out of the runtime; inject via interface).

import '../runtime/runtime_status.dart';

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
    BathSystemPreference fallback = BathSystemPreference.zhuli,
  });

  /// 持久化浴室系统偏好。
  Future<void> saveBathSystem(BathSystemPreference preference);

  /// 读取「使用模拟后端」开关（Phase 0）；无记录时返回 [fallback]。
  /// true = 强制全 Fake + InMemory（无账号/设备的开发演示）；false = 真实后端（默认）。
  /// main() 在建 adapter 前读取此值决定注入真实还是 Fake。
  Future<bool> loadUseSimulatedBackend({bool fallback = false});

  /// 持久化「使用模拟后端」开关。因 adapter 在启动时一次性构造，改动需重启才生效。
  Future<void> saveUseSimulatedBackend(bool useSimulated);
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({
    BathSystemPreference? initial,
    bool? useSimulatedBackend,
  })  : _bathSystem = initial,
        _useSimulatedBackend = useSimulatedBackend;

  BathSystemPreference? _bathSystem;
  bool? _useSimulatedBackend;

  @override
  Future<BathSystemPreference> loadBathSystem({
    BathSystemPreference fallback = BathSystemPreference.zhuli,
  }) async {
    return _bathSystem ?? fallback;
  }

  @override
  Future<void> saveBathSystem(BathSystemPreference preference) async {
    _bathSystem = preference;
  }

  @override
  Future<bool> loadUseSimulatedBackend({bool fallback = false}) async {
    return _useSimulatedBackend ?? fallback;
  }

  @override
  Future<void> saveUseSimulatedBackend(bool useSimulated) async {
    _useSimulatedBackend = useSimulated;
  }
}
