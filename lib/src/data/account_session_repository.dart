// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Account session persistence abstraction (no visual constants). Same decoupling pattern as
// SettingsRepository (roadmap §3/§4): runtime depends only on this interface.

import '../runtime/models/account_session.dart';

/// 账号 session 持久化接口（P2）。与 [SettingsRepository] 同构、分职责：
/// 不做 god repository。P2 只覆盖 Zhuli + Ujing；798 在 P3 扩展同类方法。
abstract class AccountSessionRepository {
  Future<ZhuliSession?> loadZhuli();
  Future<void> saveZhuli(ZhuliSession session);

  Future<UjingAccountUi?> loadUjing();
  Future<void> saveUjing(UjingAccountUi account);

  /// P3：798 session + 设备列表 + 当前设备 id 一起持久化。
  Future<Shower798Persisted?> loadShower798();
  Future<void> saveShower798(Shower798Persisted data);
}

/// 798 持久化聚合（session + 设备列表 + 当前设备）。
class Shower798Persisted {
  const Shower798Persisted({
    required this.account,
    this.devices = const <Shower798DeviceUi>[],
    this.currentDeviceId = '',
  });

  final Shower798AccountUi account;
  final List<Shower798DeviceUi> devices;
  final String currentDeviceId;
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
class InMemoryAccountSessionRepository implements AccountSessionRepository {
  InMemoryAccountSessionRepository({
    ZhuliSession? zhuli,
    UjingAccountUi? ujing,
    Shower798Persisted? shower798,
  })  : _zhuli = zhuli,
        _ujing = ujing,
        _shower798 = shower798;

  ZhuliSession? _zhuli;
  UjingAccountUi? _ujing;
  Shower798Persisted? _shower798;

  @override
  Future<ZhuliSession?> loadZhuli() async => _zhuli;

  @override
  Future<void> saveZhuli(ZhuliSession session) async => _zhuli = session;

  @override
  Future<UjingAccountUi?> loadUjing() async => _ujing;

  @override
  Future<void> saveUjing(UjingAccountUi account) async => _ujing = account;

  @override
  Future<Shower798Persisted?> loadShower798() async => _shower798;

  @override
  Future<void> saveShower798(Shower798Persisted data) async =>
      _shower798 = data;
}
