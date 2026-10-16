// Composition entry for the application runtime. State/enums and per-service actions are split
// into runtime_status / shui_home_state / shui_runtime_base / actions/* and re-exported here,
// so existing consumers keep importing this single file unchanged.

import 'package:flutter/widgets.dart';

import '../data/account_session_repository.dart';
import '../data/adapters/hotwater_adapter.dart';
import '../data/adapters/shower798_adapter.dart';
import '../data/adapters/ujing_adapter.dart';
import '../data/app_bootstrap.dart';
import '../data/legacy_data_migration.dart';
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
import '../data/washer_history_repository.dart';
import '../data/shared_prefs_washer_history_repository.dart';
import 'actions/account_actions.dart';
import 'actions/legacy_recovery_actions.dart';
import 'actions/account_availability_actions.dart';
import 'actions/devices_actions.dart';
import 'actions/home_actions.dart';
import 'actions/hotwater_actions.dart';
import 'actions/shower798_actions.dart';
import 'actions/washer_actions.dart';
import 'actions/water_actions.dart';
import 'live_clock.dart';
import 'diagnostic_log.dart';
import 'shui_runtime_base.dart';

export 'runtime_status.dart';
export 'shui_home_state.dart';

/// 组装各服务操作与旧数据恢复流程；业务适配器和安全仓库必须显式注入。
class ShuiRuntime extends ShuiRuntimeBase
    with
        LegacyRecoveryActions,
        HomeActions,
        DevicesActions,
        WaterActions,
        AccountActions,
        Shower798Actions,
        WasherActions,
        HotwaterActions,
        AccountAvailabilityActions {
  ShuiRuntime({
    super.settings,
    super.sessions,
    super.devices,
    super.history,
    super.water,
    super.washerHistory,
    required super.secure,
    required super.migration,
    super.clock,
    required super.ujing,
    required super.hotwater,
    required super.shower798,
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
    this.washerHistory,
    required this.secure,
    required this.migration,
    this.clock,
    required this.ujing,
    required this.hotwater,
    required this.shower798,
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

  final WaterOrderRepository? water;

  final WasherHistoryRepository? washerHistory;

  /// 可选注入的敏感凭证持久化（测试传内存实现）。默认生产用 flutter_secure_storage。
  final SecureSessionRepository secure;
  final LegacyDataMigration migration;

  /// 可选注入的时间源（测试传 FixedLiveClock 保证 golden 确定性）。
  final LiveClock? clock;

  /// 必须显式注入的 U净适配器；生产使用 UjingHttpAdapter。
  final IUjingAdapter ujing;

  /// 必须显式注入的住理适配器；生产使用 RealZhuliAdapter。
  final IHotwaterAdapter hotwater;

  /// 必须显式注入的 798 适配器；生产使用 RealShower798Adapter。
  final IShower798Adapter shower798;

  final DiagnosticLog? diagnosticLog;
  final String? appVersion;

  /// 可选预加载的持久化快照（main() 启动前已 await 读出，消除首帧闪烁）。
  /// 为 null 时由 runtime 异步从 repository 回填（测试路径）。
  final PersistedSnapshot? initial;

  static ShuiRuntime of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShuiRuntimeInherited>();
    assert(scope != null, 'ShuiRuntimeScope is missing from the widget tree.');
    return scope!.runtime;
  }

  @override
  State<ShuiRuntimeScope> createState() => _ShuiRuntimeScopeState();
}

class _ShuiRuntimeScopeState extends State<ShuiRuntimeScope>
    with WidgetsBindingObserver {
  late final ShuiRuntime runtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    runtime = ShuiRuntime(
      settings: widget.settings ?? SharedPrefsSettingsRepository(),
      sessions: widget.sessions ?? SharedPrefsAccountSessionRepository(),
      devices: widget.devices ?? SharedPrefsLocalDeviceRepository(),
      history: widget.history ?? SharedPrefsHistoryRepository(),
      water: widget.water ?? SharedPrefsWaterOrderRepository(),
      washerHistory:
          widget.washerHistory ?? SharedPrefsWasherHistoryRepository(),
      secure: widget.secure,
      clock: widget.clock,
      ujing: widget.ujing,
      hotwater: widget.hotwater,
      shower798: widget.shower798,
      diagnosticLog: widget.diagnosticLog,
      appVersion: widget.appVersion,
      initial: widget.initial,
      migration: widget.migration,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    runtime.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    runtime.setPollingPaused(state != AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return _ShuiRuntimeInherited(runtime: runtime, child: widget.child);
  }
}

class _ShuiRuntimeInherited extends InheritedNotifier<ShuiRuntime> {
  const _ShuiRuntimeInherited({required this.runtime, required super.child})
      : super(notifier: runtime);

  final ShuiRuntime runtime;
}
