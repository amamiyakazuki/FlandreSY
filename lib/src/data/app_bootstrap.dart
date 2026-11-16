// App bootstrap: single source for loading persisted state (settings + account sessions).
// Used by main() preload (no first-frame flash) and runtime async restore alike.

import '../runtime/models/account_session.dart';
import '../runtime/models/hotwater_history.dart';
import '../runtime/models/local_device.dart';
import '../runtime/models/water_order.dart';
import '../runtime/models/washer_order.dart';
import '../runtime/runtime_status.dart';
import '../runtime/hotwater_state.dart';
import 'account_session_repository.dart';
import 'history_repository.dart';
import 'local_device_repository.dart';
import 'settings_repository.dart';
import 'water_order_repository.dart';
import 'washer_history_repository.dart';

/// 启动时从持久化层恢复的聚合快照。main() 预加载注入 → 消除首帧闪烁（P1 Major 1 模式）；
/// runtime 也用同一 [AppBootstrap.load] 异步恢复，避免预加载/恢复逻辑双源。
class PersistedSnapshot {
  const PersistedSnapshot({
    required this.bathSystem,
    this.permissionIntroSeen = false,
    this.zhuli,
    this.ujing,
    this.shower798,
    this.localDevices,
    this.hotwaterHistory,
    this.hotwaterSession,
    this.waterOrders = const [],
    this.waterHistory,
    this.washerHistory,
    this.washerOrders = const [],
    this.recoveryWarnings = const [],
  });

  final BathSystemPreference bathSystem;

  final bool permissionIntroSeen;

  final ZhuliSession? zhuli;
  final UjingAccountUi? ujing;
  final Shower798Persisted? shower798;

  /// 本地设备列表（PDEV）。null = 从未持久化过（首启空列表）；非 null = 整体替换 seed。
  final List<LocalDeviceShortcut>? localDevices;

  /// 热水历史（PHIST）。null = 从未持久化过（首启走 adapter 拉取）；非 null = 写入 hotwater.history。
  final List<HotwaterHistoryUi>? hotwaterHistory;
  final HotwaterSession? hotwaterSession;
  final List<WaterOrderUi> waterOrders;
  final List<WaterOrderHistoryUi>? waterHistory;
  final List<WasherOrderHistoryUi>? washerHistory;
  final List<WasherOrderUi> washerOrders;

  /// 读取失败的数据域（仅用于诊断日志；失败的域按空数据继续运行，不再锁住功能）。
  final List<String> recoveryWarnings;
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
    WaterOrderRepository water,
    WasherHistoryRepository washerHistory,
  ) async {
    final warnings = <String>[];
    Future<T?> recover<T>(String domain, Future<T> Function() load) async {
      try {
        return await load();
      } catch (error) {
        warnings.add('$domain 读取失败（${error.runtimeType}），已按空数据继续');
        return null;
      }
    }

    final bathSystem = await recover('洗浴偏好', settings.loadBathSystem) ??
        BathSystemPreference.none;
    final permissionIntroSeen =
        await recover('权限引导', settings.loadPermissionIntroSeen) ?? false;
    final zhuli = await recover('住理账号', sessions.loadZhuli);
    final ujing = await recover('U净账号', sessions.loadUjing);
    final shower798 = await recover('798账号', sessions.loadShower798);
    final localDevices = await recover('本地设备', devices.loadDevices);
    final hotwaterHistory = await recover('热水历史', history.loadHistory);
    final hotwaterSession = await recover('热水会话', settings.loadHotwaterSession);
    final waterSnapshot = await recover('饮水订单', water.load);
    final washerSnapshot = await recover('洗衣订单', washerHistory.load);
    return PersistedSnapshot(
      bathSystem: bathSystem,
      permissionIntroSeen: permissionIntroSeen,
      zhuli: zhuli,
      ujing: ujing,
      shower798: shower798,
      localDevices: localDevices,
      hotwaterHistory: hotwaterHistory,
      hotwaterSession: hotwaterSession,
      waterOrders: waterSnapshot?.orders ?? const [],
      waterHistory: waterSnapshot?.history,
      washerHistory: washerSnapshot?.history,
      washerOrders: washerSnapshot?.orders ?? const [],
      recoveryWarnings: warnings,
    );
  }
}
