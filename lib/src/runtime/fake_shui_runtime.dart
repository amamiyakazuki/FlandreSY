// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Composition entry for the fake runtime. State/enums and per-service actions are split
// into runtime_status / shui_home_state / shui_runtime_base / actions/* and re-exported here,
// so existing consumers keep importing this single file unchanged.

import 'package:flutter/widgets.dart';

import '../data/account_session_repository.dart';
import '../data/adapters/hotwater_adapter.dart';
import '../data/adapters/shower798_adapter.dart';
import '../data/adapters/ujing_adapter.dart';
import '../data/app_bootstrap.dart';
import '../data/history_repository.dart';
import '../data/local_device_repository.dart';
import '../data/secure_session_repository.dart';
import '../data/settings_repository.dart';
import '../data/shared_prefs_account_session_repository.dart';
import '../data/shared_prefs_history_repository.dart';
import '../data/shared_prefs_local_device_repository.dart';
import '../data/shared_prefs_settings_repository.dart';
import '../data/shared_prefs_water_order_repository.dart';
import '../data/water_order_repository.dart';
import 'actions/account_actions.dart';
import 'actions/devices_actions.dart';
import 'actions/home_actions.dart';
import 'actions/hotwater_actions.dart';
import 'actions/shower798_actions.dart';
import 'actions/washer_actions.dart';
import 'actions/water_actions.dart';
import 'diagnostic_log.dart';
import 'live_clock.dart';
import 'shui_runtime_base.dart';

export 'runtime_status.dart';
export 'shui_home_state.dart';

/// Fake 运行时：组装各服务 action mixin 到统一的 [ShuiRuntimeBase]。
/// 后续接真实 adapter 时，可按服务替换为独立 runtime / 真实 mixin，结构已就位。
class FakeShuiRuntime extends ShuiRuntimeBase
    with
        HomeActions,
        DevicesActions,
        WaterActions,
        AccountActions,
        Shower798Actions,
        WasherActions,
        HotwaterActions {
  FakeShuiRuntime({
    super.settings,
    super.sessions,
    super.devices,
    super.history,
    super.water,
    super.secure,
    super.clock,
    super.ujing,
    super.hotwater,
    super.shower798,
    super.diagnosticLog,
    super.appVersion,
    super.initial,
  });
}

class ShuiRuntimeScope extends StatefulWidget {
  const ShuiRuntimeScope({
    required this.child,
    this.settings,
    this.sessions,
    this.devices,
    this.history,
    this.water,
    this.secure,
    this.clock,
    this.ujing,
    this.hotwater,
    this.shower798,
    this.diagnosticLog,
    this.appVersion,
    this.initial,
    super.key,
  });

  final Widget child;

  /// 可选注入的设置持久化（测试传内存实现）。默认生产用 shared_preferences。
  final SettingsRepository? settings;

  /// 可选注入的账号 session 持久化（测试传内存实现）。默认生产用 shared_preferences。
  final AccountSessionRepository? sessions;

  /// 可选注入的本地设备持久化（测试/golden 传内存实现预置设备）。默认生产用 shared_preferences。
  final LocalDeviceRepository? devices;

  /// 可选注入的热水历史持久化（测试传内存实现）。默认生产用 shared_preferences。
  final HistoryRepository? history;

  /// 可选注入的饮水订单持久化（PWATER 问题7；测试传内存实现）。默认生产用 shared_preferences。
  final WaterOrderRepository? water;

  /// 可选注入的敏感凭证持久化（测试传内存实现）。默认生产用 flutter_secure_storage。
  final SecureSessionRepository? secure;

  /// 可选注入的时间源（测试传 FixedLiveClock 保证 golden 确定性）。
  final LiveClock? clock;

  /// 可选注入的 Ujing 适配器（默认 FakeUjingAdapter；真机验证注入 UjingHttpAdapter）。
  final IUjingAdapter? ujing;

  /// 可选注入的 Zhuli 热水适配器（默认 FakeHotwaterAdapter；真机验证注入 RealZhuliAdapter）。
  final IHotwaterAdapter? hotwater;

  /// 可选注入的 798 洗浴适配器（默认 FakeShower798Adapter；真机验证注入 RealShower798Adapter）。
  final IShower798Adapter? shower798;

  /// 可选注入的诊断日志器（M-REAL）。默认 InMemory（测试不落盘）；main() 注入持久化实现 + adapter 埋点。
  final DiagnosticLog? diagnosticLog;

  /// 可选注入的真实 App 版本号（M-REAL PackageInfo.version）。null → 常量兜底。
  final String? appVersion;

  /// 可选预加载的持久化快照（main() 启动前已 await 读出，消除首帧闪烁）。
  /// 为 null 时由 runtime 异步从 repository 回填（测试路径）。
  final PersistedSnapshot? initial;

  static FakeShuiRuntime of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShuiRuntimeInherited>();
    assert(scope != null, 'ShuiRuntimeScope is missing from the widget tree.');
    return scope!.runtime;
  }

  @override
  State<ShuiRuntimeScope> createState() => _ShuiRuntimeScopeState();
}

class _ShuiRuntimeScopeState extends State<ShuiRuntimeScope> {
  late final FakeShuiRuntime runtime;

  @override
  void initState() {
    super.initState();
    runtime = FakeShuiRuntime(
      settings: widget.settings ?? SharedPrefsSettingsRepository(),
      sessions: widget.sessions ?? SharedPrefsAccountSessionRepository(),
      devices: widget.devices ?? SharedPrefsLocalDeviceRepository(),
      history: widget.history ?? SharedPrefsHistoryRepository(),
      water: widget.water ?? SharedPrefsWaterOrderRepository(),
      secure: widget.secure, // null → base 默认 InMemory；real 模式由 main() 注入 flutter_secure_storage
      clock: widget.clock,
      ujing: widget.ujing,
      hotwater: widget.hotwater,
      shower798: widget.shower798,
      diagnosticLog: widget.diagnosticLog,
      appVersion: widget.appVersion,
      initial: widget.initial,
    );
  }

  @override
  void dispose() {
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShuiRuntimeInherited(runtime: runtime, child: widget.child);
  }
}

class _ShuiRuntimeInherited extends InheritedNotifier<FakeShuiRuntime> {
  const _ShuiRuntimeInherited({required this.runtime, required super.child})
      : super(notifier: runtime);

  final FakeShuiRuntime runtime;
}
