// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// App bootstrap: single source for loading persisted state (settings + account sessions).
// Used by main() preload (no first-frame flash) and runtime async restore alike.

import '../runtime/models/account_session.dart';
import '../runtime/models/hotwater_history.dart';
import '../runtime/models/local_device.dart';
import '../runtime/runtime_status.dart';
import 'account_session_repository.dart';
import 'history_repository.dart';
import 'local_device_repository.dart';
import 'settings_repository.dart';

/// 启动时从持久化层恢复的聚合快照。main() 预加载注入 → 消除首帧闪烁（P1 Major 1 模式）；
/// runtime 也用同一 [AppBootstrap.load] 异步恢复，避免预加载/恢复逻辑双源。
class PersistedSnapshot {
  const PersistedSnapshot({
    required this.bathSystem,
    this.useSimulatedBackend = false,
    this.zhuli,
    this.ujing,
    this.shower798,
    this.localDevices,
    this.hotwaterHistory,
  });

  final BathSystemPreference bathSystem;

  /// 「使用模拟后端」开关（Phase 0）。true = 强制 Fake + InMemory；false = 真实后端（默认）。
  /// main() 在 await 本快照后、建 adapter 前读取此值决定注入真实还是 Fake。
  final bool useSimulatedBackend;

  final ZhuliSession? zhuli;
  final UjingAccountUi? ujing;
  final Shower798Persisted? shower798;

  /// 本地设备列表（PDEV）。null = 从未持久化过（首启空列表）；非 null = 整体替换 seed。
  final List<LocalDeviceShortcut>? localDevices;

  /// 热水历史（PHIST）。null = 从未持久化过（首启走 adapter 拉取）；非 null = 写入 hotwater.history。
  final List<HotwaterHistoryUi>? hotwaterHistory;
}

/// 合并 SettingsRepository + AccountSessionRepository + LocalDeviceRepository +
/// HistoryRepository 的恢复逻辑（单一来源）。
class AppBootstrap {
  const AppBootstrap._();

  static Future<PersistedSnapshot> load(
    SettingsRepository settings,
    AccountSessionRepository sessions,
    LocalDeviceRepository devices,
    HistoryRepository history,
  ) async {
    final bathSystem = await settings.loadBathSystem();
    final useSimulatedBackend = await settings.loadUseSimulatedBackend();
    final zhuli = await sessions.loadZhuli();
    final ujing = await sessions.loadUjing();
    final shower798 = await sessions.loadShower798();
    final localDevices = await devices.loadDevices();
    final hotwaterHistory = await history.loadHistory();
    return PersistedSnapshot(
      bathSystem: bathSystem,
      useSimulatedBackend: useSimulatedBackend,
      zhuli: zhuli,
      ujing: ujing,
      shower798: shower798,
      localDevices: localDevices,
      hotwaterHistory: hotwaterHistory,
    );
  }
}
