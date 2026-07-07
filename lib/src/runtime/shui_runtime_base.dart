// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Runtime base: holds aggregate state + notify plumbing. Service actions live in mixins
// (home/devices/water) to keep each concern small and swappable for real adapters later.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/account_session_repository.dart';
import '../data/diagnostic_log_repository.dart';
import '../data/adapters/fake_hotwater_adapter.dart';
import '../data/adapters/fake_shower798_adapter.dart';
import '../data/adapters/fake_ujing_adapter.dart';
import '../data/adapters/hotwater_adapter.dart';
import '../data/adapters/real_shower798_adapter.dart';
import '../data/adapters/real_zhuli_adapter.dart';
import '../data/adapters/shower798_adapter.dart';
import '../data/adapters/ujing_adapter.dart';
import '../data/adapters/ujing_http_adapter.dart';
import '../data/app_bootstrap.dart';
import '../data/history_repository.dart';
import '../data/local_device_repository.dart';
import '../data/secure_session_repository.dart';
import '../data/settings_repository.dart';
import '../data/water_order_repository.dart';
import '../more/version_check.dart' show kCurrentAppVersion;
import 'diagnostic_log.dart';
import 'live_clock.dart';
import 'models/account_session.dart';
import 'models/hotwater_history.dart';
import 'models/local_device.dart';
import 'models/water_order.dart';
import 'runtime_status.dart';
import 'shui_home_state.dart';

/// 需重登的服务标识（RELOG）。action 层捕获 authInvalid 后据此清对应服务的凭证 + 账号 state。
enum AuthService { ujing, zhuli, shower798 }

/// 运行时基类：持有聚合 [ShuiHomeState] + 通知管线 + 共享计时器。
/// 各服务的 action 以 mixin（on ShuiRuntimeBase）形式拆分，避免单文件聚合膨胀。
abstract class ShuiRuntimeBase extends ChangeNotifier {
  ShuiRuntimeBase({
    SettingsRepository? settings,
    AccountSessionRepository? sessions,
    LocalDeviceRepository? devices,
    HistoryRepository? history,
    WaterOrderRepository? water,
    SecureSessionRepository? secure,
    LiveClock? clock,
    IUjingAdapter? ujing,
    IHotwaterAdapter? hotwater,
    IShower798Adapter? shower798,
    DiagnosticLog? diagnosticLog,
    String? appVersion,
    PersistedSnapshot? initial,
  })  : settings = settings ?? InMemorySettingsRepository(),
        sessions = sessions ?? InMemoryAccountSessionRepository(),
        devices = devices ?? InMemoryLocalDeviceRepository(),
        history = history ?? InMemoryHistoryRepository(),
        water = water ?? InMemoryWaterOrderRepository(),
        secure = secure ?? InMemorySecureSessionRepository(),
        clock = clock ?? const SystemLiveClock(),
        ujing = ujing ?? const FakeUjingAdapter(),
        hotwater = hotwater ?? const FakeHotwaterAdapter(),
        shower798 = shower798 ?? FakeShower798Adapter(),
        diagnosticLog =
            diagnosticLog ?? DiagnosticLog(repo: InMemoryDiagnosticLogRepository()),
        appVersion = appVersion ?? kCurrentAppVersion,
        _state = initial == null ? seedState() : _applySnapshot(initial) {
    // 恢复 deviceSeq / hotwaterOrderSeq 起点，避免新增 id 与已持久化数据撞号。
    deviceSeq = _maxDeviceSeq(_state.localDevices);
    hotwaterOrderSeq = _maxOrderSeq(_state.hotwater.history);
    // 若已由 main() 预加载注入快照（生产路径，消除首帧闪烁），无需再异步回填；
    // 否则（测试/未预加载）从 repository 异步恢复，完成后 emit 一次。
    if (initial == null) {
      _restorePersisted();
    }
  }

  /// 设置持久化（P1）。runtime 只依赖接口，生产注入 shared_prefs，测试注入内存实现。
  final SettingsRepository settings;

  /// 账号 session 持久化（P2）。同 settings 解耦模式。
  final AccountSessionRepository sessions;

  /// 本地设备列表持久化（PDEV）。同 settings/sessions 解耦模式。
  final LocalDeviceRepository devices;

  /// 热水历史持久化（PHIST）。同 settings/sessions/devices 解耦模式。
  final HistoryRepository history;

  /// 饮水订单持久化（PWATER 问题7）。当前订单 + 历史。同上解耦模式。
  final WaterOrderRepository water;

  /// 敏感凭证持久化（PTOK）。token/secretKey 加密存储；action 层登录成功后写入。
  /// 默认 InMemory（测试确定）；生产 real 模式注入 flutter_secure_storage 实现。
  final SecureSessionRepository secure;

  /// 时间源（W2 live 倒计时）。生产 SystemLiveClock，测试 FixedLiveClock。
  final LiveClock clock;

  /// Ujing 后端适配器（P4 A1）。生产默认注入 UjingHttpAdapter（Phase 0 翻真）；
  /// 未注入（null）→ FakeUjingAdapter，用于测试/golden 及模拟后端模式。
  final IUjingAdapter ujing;

  /// Zhuli 热水适配器（P4 Z1）。生产默认注入 RealZhuliAdapter；
  /// 未注入（null）→ FakeHotwaterAdapter（测试/golden/模拟模式）。
  final IHotwaterAdapter hotwater;

  /// 慧生活798 洗浴适配器（P4 S798）。生产默认注入 RealShower798Adapter；
  /// 未注入（null）→ FakeShower798Adapter（测试/golden/模拟模式）。
  final IShower798Adapter shower798;

  /// 诊断日志器（M-REAL 日志与诊断）。真实 adapter 埋点写入，日志页读。
  /// 未注入 → InMemory（测试/模拟模式，不落盘）。
  final DiagnosticLog diagnosticLog;

  /// 真实 App 版本号（M-REAL）。main() 传 PackageInfo.version；未注入 → 常量兜底。
  /// About / 检查版本 / 版本行读它。
  final String appVersion;

  ShuiHomeState _state;

  ShuiHomeState get state => _state;

  /// 统一状态写入 + 通知。mixin 通过它更新状态，避免直接触碰私有字段。
  void emit(ShuiHomeState next) {
    _state = next;
    notifyListeners();
  }

  /// RELOG：服务端明确拒绝当前凭证（authInvalid）时统一清理 + 引导重登。
  /// 三步：清 secure 落盘凭证 → 清 adapter 内存凭证（real adapter 才有 invalidateAuth，
  /// 用类型判断，复用 PTOK 的 `is` 范式）→ 清账号 state + 置该服务 loginRequired。
  /// 不主动导航；UI 靠既有 loginRequired 橙色 banner + 静态「重新登录」入口引导（用户已定）。
  Future<void> handleAuthInvalidation(AuthService service) async {
    const message = '登录已失效，请重新登录';
    switch (service) {
      case AuthService.ujing:
        await secure.clearUjingToken();
        final adapter = ujing;
        if (adapter is UjingHttpAdapter) {
          adapter.invalidateAuth();
        }
        emit(state.copyWith(
          clearUjingAccount: true,
          washerLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.loginRequired,
            message: message,
          ),
        ));
      case AuthService.zhuli:
        await secure.clearZhuliSession();
        final adapter = hotwater;
        if (adapter is RealZhuliAdapter) {
          adapter.invalidateAuth();
        }
        emit(state.copyWith(
          zhuli: const ZhuliSession(phone: ''),
          hotwaterLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.loginRequired,
            message: message,
          ),
        ));
      case AuthService.shower798:
        await secure.clearShower798Token();
        final adapter = shower798;
        if (adapter is RealShower798Adapter) {
          adapter.invalidateAuth();
        }
        emit(state.copyWith(
          clearShower798Account: true,
          shower798Devices: const <Shower798DeviceUi>[],
          currentShower798DeviceId: '',
          shower798Login: const RuntimeActionStatus(
            state: RuntimeTaskState.loginRequired,
            message: message,
          ),
        ));
    }
  }

  /// 把持久化快照应用到 seed state（main 预加载 + 异步恢复共用，避免双源）。
  static ShuiHomeState _applySnapshot(PersistedSnapshot snap) {
    final base = seedState();
    return base.copyWith(
      bathSystemPreference: snap.bathSystem,
      useSimulatedBackend: snap.useSimulatedBackend,
      zhuli: snap.zhuli,
      hotwaterLogin: snap.zhuli?.isLoggedIn ?? false
          ? RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '住理生活已登录：${snap.zhuli!.phone}',
            )
          : base.hotwaterLogin,
      ujingAccount: snap.ujing,
      washerLogin: snap.ujing != null
          ? const RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: 'U净已登录',
            )
          : base.washerLogin,
      shower798Account: snap.shower798?.account,
      shower798Devices: snap.shower798?.devices,
      currentShower798DeviceId: snap.shower798?.currentDeviceId,
      shower798Login: snap.shower798 != null
          ? RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '慧生活798账号：${snap.shower798!.account.mobile}',
            )
          : base.shower798Login,
      // PDEV：持久化设备列表非 null 时整体替换 seed（含空列表 = 用户删空，绝不 re-seed）。
      localDevices: snap.localDevices,
      // P1-FIX：恢复时不再假冒「刚刚」（无真实刷新时刻可用）。留空 → UI 显「未刷新」，
      // 用户点刷新后才按真实时钟打戳（见 refreshLocalDevices）。
      localDevicesLastRefreshed: null,
      // PHIST：持久化热水历史非 null 时写入 hotwater.history（null → 保持空 → 首启走 adapter 拉取）。
      hotwaterHistory: snap.hotwaterHistory,
      // PWATER（问题7）：恢复当前接水订单 + 历史。currentWaterOrder 用显式 clear 语义——
      // 快照为 null 表示无当前订单（不覆盖 seed 的 null）；非 null 则恢复。history 同理。
      currentWaterOrder: snap.currentWaterOrder,
      waterHistory: snap.waterHistory ?? const <WaterOrderHistoryUi>[],
    );
  }

  /// 启动时回填已持久化状态（异步，完成后 emit 一次）。与预加载共用 AppBootstrap。
  Future<void> _restorePersisted() async {
    final snap =
        await AppBootstrap.load(settings, sessions, devices, history, water);
    final restored = _applySnapshot(snap);
    deviceSeq = _maxDeviceSeq(restored.localDevices);
    hotwaterOrderSeq = _maxOrderSeq(restored.hotwater.history);
    emit(restored);
  }

  /// 从热水历史派生 hotwaterOrderSeq 起点：取 orderId 尾号（如「热水-3」）的最大值，避免 append 撞号。
  static int _maxOrderSeq(List<HotwaterHistoryUi> history) {
    var max = 0;
    for (final h in history) {
      final match = RegExp(r'-(\d+)$').firstMatch(h.orderId);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) {
          max = n;
        }
      }
    }
    return max;
  }

  /// 从设备列表派生 deviceSeq 起点：取 sortOrder 与 preset-/scanned- id 尾号的最大值。
  static int _maxDeviceSeq(List<LocalDeviceShortcut> list) {
    var max = 0;
    for (final d in list) {
      if (d.sortOrder > max) {
        max = d.sortOrder;
      }
      final match = RegExp(r'-(\d+)$').firstMatch(d.id);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) {
          max = n;
        }
      }
    }
    return max;
  }

  /// 自增计数器，用于在 fake 环境生成稳定且唯一的设备 id / 设备号。
  /// 初始 0；构造 + 恢复后由 [_maxDeviceSeq] 置为已存在设备的最大序号，避免撞号。
  int deviceSeq = 0;

  /// 热水历史订单号自增计数器（PHIST）。初始 0；构造 + 恢复后由 [_maxOrderSeq]
  /// 置为已持久化历史 orderId 尾号的最大值，避免 append 撞号。HotwaterActions 读写它。
  int hotwaterOrderSeq = 0;

  /// Home banner 清理计时器（waterScan/washerScan）。
  Timer? _homeBannerTimer;

  /// Devices/Water 提示清理计时器。两个计时器独立，行为与拆分前一致。
  Timer? _deviceNoticeTimer;

  /// 热水错误提示清理计时器（问题2：3 秒自动消失）。独立于上两者。
  Timer? _hotwaterErrorTimer;

  /// 注册 Home banner 延后清理（4 秒）。重复调用取消上一个。
  void scheduleHomeBannerClear(VoidCallback onClear) {
    _homeBannerTimer?.cancel();
    _homeBannerTimer = Timer(const Duration(seconds: 4), onClear);
  }

  /// 注册 Devices/Water 提示延后清理（4 秒）。重复调用取消上一个。
  void scheduleDeviceNoticeClear(VoidCallback onClear) {
    _deviceNoticeTimer?.cancel();
    _deviceNoticeTimer = Timer(const Duration(seconds: 4), onClear);
  }

  /// 注册热水错误提示延后清理（问题2：热水开/关失败或需登录的警告 3 秒自动消失）。
  /// 重复调用取消上一个。成功态不走此清理（当前状态需一直可见）。
  void scheduleHotwaterErrorClear(VoidCallback onClear) {
    _hotwaterErrorTimer?.cancel();
    _hotwaterErrorTimer = Timer(const Duration(seconds: 3), onClear);
  }

  @override
  void dispose() {
    _homeBannerTimer?.cancel();
    _deviceNoticeTimer?.cancel();
    _hotwaterErrorTimer?.cancel();
    super.dispose();
  }

  /// 持久化当前饮水订单 + 历史（PWATER 问题7，fire-and-forget，对齐 _persistHistory 范式）。
  /// 创建订单后、完成转历史后均调用，使重启后订单页饮水分类可恢复。
  void persistWaterOrders() {
    unawaited(
      water.save(
        WaterOrderSnapshot(
          currentOrder: state.currentWaterOrder,
          history: state.waterHistory,
        ),
      ),
    );
  }

  /// 初始种子：空设备列表起步（PDEV）。设备由用户扫码/预设添加，添加后持久化，
  /// 重启从 [LocalDeviceRepository] 恢复用户的真实列表。首启无持久化记录 → 空列表。
  static ShuiHomeState seedState() {
    return const ShuiHomeState(
      localDevices: <LocalDeviceShortcut>[],
    );
  }
}
