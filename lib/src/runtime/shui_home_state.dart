// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Immutable aggregate UI state (no visual constants). Split out of fake_shui_runtime.dart.

import 'package:flutter/foundation.dart';

import 'account_state.dart';
import 'hotwater_state.dart';
import 'models/account_session.dart';
import 'models/hotwater_history.dart';
import 'models/local_device.dart';
import 'models/washer_order.dart';
import 'models/water_order.dart';
import 'runtime_status.dart';
import 'washer_state.dart';

/// 聚合 UI 状态（Home + Devices + DrinkingWater）。不可变 + copyWith。
/// 注意：Home 设备统计从 [localDevices] 派生，保持单一来源（B1 双源消除）。
@immutable
class ShuiHomeState {
  const ShuiHomeState({
    this.waterScan = const RuntimeActionStatus(
      state: RuntimeTaskState.idle,
      message: '扫描饮水机或洗衣机二维码',
    ),
    this.washerScan = const RuntimeActionStatus(),
    this.bathSystemPreference = BathSystemPreference.zhuli,
    this.useSimulatedBackend = false,
    this.localDevices = const <LocalDeviceShortcut>[],
    this.localDevicesLastRefreshed = '',
    this.devicesRefresh = const RuntimeActionStatus(),
    this.waterReady,
    this.currentWaterOrder,
    this.waterOrder = const RuntimeActionStatus(),
    this.waterHistory = const <WaterOrderHistoryUi>[],
    // ===== H1 热水控制子状态（默认待启动；进行中任务由 homeTasks 从真实运行态派生）=====
    this.hotwater = const HotwaterState(),
    // ===== P2 账号登录子状态（拆分到 AccountState，防顶层膨胀）=====
    this.account = const AccountState(),
    // ===== W1 洗衣下单子状态（同 AccountState 拆分范式）=====
    this.washer = const WasherState(),
  });

  final RuntimeActionStatus waterScan;
  final RuntimeActionStatus washerScan;
  final BathSystemPreference bathSystemPreference;

  /// 「使用模拟后端」开关（Phase 0）。反映持久化/待生效值；改后需重启才真正切换 adapter。
  final bool useSimulatedBackend;

  // ===== H1 热水控制子状态 =====
  /// 热水控制子状态（running/start/stop/history）。
  final HotwaterState hotwater;

  // 便捷委托 getter：保持既有读取路径稳定（state.hotwaterRunning 等）。
  bool get hotwaterRunning => hotwater.running;
  RuntimeActionStatus get hotwaterStart => hotwater.start;
  RuntimeActionStatus get hotwaterStop => hotwater.stop;
  List<HotwaterHistoryUi> get hotwaterHistory => hotwater.history;

  /// 本地快捷设备列表（B1）。Home 的设备统计从此派生，保持单一来源。
  final List<LocalDeviceShortcut> localDevices;

  /// 最近一次刷新时间文案（Devices RefreshBar 用）。
  final String localDevicesLastRefreshed;

  /// 刷新动作状态（loading 时禁用刷新，避免并发）。
  final RuntimeActionStatus devicesRefresh;

  /// 当前饮水机 ready 信息（扫码确认校区/余额，B2）。
  final WaterReadyUi? waterReady;

  /// 当前接水订单（创建后存在，完成后清空，B2）。
  final WaterOrderUi? currentWaterOrder;

  /// 饮水订单动作状态（scan/create/refresh 的 loading/success/failure）。
  final RuntimeActionStatus waterOrder;

  /// 饮水完成历史（本地累积，B2）。
  final List<WaterOrderHistoryUi> waterHistory;

  // ===== P2 账号登录子状态 =====
  /// 账号登录子状态（Zhuli + U净；P3 的 798 也归入）。
  final AccountState account;

  // ===== W1 洗衣下单子状态 =====
  /// 洗衣下单子状态（program/order/payment/history）。
  final WasherState washer;

  // 便捷委托 getter：保持 UI 读取路径稳定（state.zhuli 等），实际存于 [account]。
  ZhuliSession get zhuli => account.zhuli;
  RuntimeActionStatus get hotwaterLogin => account.hotwaterLogin;
  UjingAccountUi? get ujingAccount => account.ujingAccount;
  RuntimeActionStatus get washerLogin => account.washerLogin;
  RuntimeActionStatus get ujingCaptcha => account.ujingCaptcha;
  int get ujingCaptchaSentAtMillis => account.ujingCaptchaSentAtMillis;
  Shower798AccountUi? get shower798Account => account.shower798Account;
  RuntimeActionStatus get shower798Login => account.shower798Login;
  RuntimeActionStatus get shower798Captcha => account.shower798Captcha;
  int get shower798CaptchaSentAtMillis => account.shower798CaptchaSentAtMillis;
  String? get shower798CaptchaImageBase64 => account.shower798CaptchaImageBase64;
  List<Shower798DeviceUi> get shower798Devices => account.shower798Devices;
  String get currentShower798DeviceId => account.currentShower798DeviceId;

  // W1 洗衣委托 getter。
  WasherProgramUi? get washerProgram => washer.program;
  WasherOrderUi? get currentWasherOrder => washer.currentOrder;
  WasherPaymentUi? get currentWasherPayment => washer.payment;
  List<WasherOrderHistoryUi> get washerHistory => washer.history;
  RuntimeActionStatus get washerOrder => washer.washerOrder;
  RuntimeActionStatus get washerPayment => washer.washerPayment;

  /// Devices 列表只展示 Washer + DrinkingWater 两类（对齐 legacy 过滤）。
  List<LocalDeviceShortcut> get visibleDevices => localDevices
      .where(
        (d) =>
            d.deviceType == LocalDeviceType.washer ||
            d.deviceType == LocalDeviceType.drinkingWater,
      )
      .toList();

  /// Home「洗衣设备」卡的「已添加」台数：派生自洗衣类设备。
  int get localWasherCount =>
      localDevices.where((d) => d.deviceType == LocalDeviceType.washer).length;

  /// Home「洗衣设备」卡的「空闲/可用」台数：lastStatus 标记为「可下单」的洗衣机。
  int get availableWasherCount => localDevices
      .where(
        (d) => d.deviceType == LocalDeviceType.washer && d.lastStatus == '可下单',
      )
      .length;

  /// Home「进行中」任务，完全从真实运行态/订单派生（对齐 legacy ShuiUiModels.kt homeTasks）。
  /// 首启无运行态、无订单 → 空列表 → OngoingCard 渲染「无任务」空态（不再伪造 3 张 demo 卡）。
  List<HomeTaskUi> get homeTasks {
    final tasks = <HomeTaskUi>[];
    // 热水：开热水成功且未关闭（对齐 legacy hotwaterActive 判据）。
    final hotwaterActive =
        hotwaterStart.state == RuntimeTaskState.success &&
            hotwaterStop.state != RuntimeTaskState.success;
    if (hotwaterActive) {
      tasks.add(
        HomeTaskUi(
          target: HomeTaskTarget.hotwater,
          title: '热水使用中',
          extra: hotwaterStart.message ?? '热水已开启',
          asset: 'shui_reshui.png',
        ),
      );
    }
    // 洗衣：存在非终态当前订单（对齐 legacy currentWasherOrder?.takeUnless{isTerminal}）。
    final washerOrder = currentWasherOrder;
    if (washerOrder != null && !washerOrder.isTerminal) {
      tasks.add(
        HomeTaskUi(
          target: HomeTaskTarget.washer,
          title: _washerTaskTitle(washerOrder),
          extra: _washerTaskExtra(washerOrder),
          asset: 'shui_yifu.png',
        ),
      );
    }
    // 饮水：存在非终态当前订单（对齐 legacy currentWaterOrder?.takeUnless{isTerminal}）。
    final waterOrder = currentWaterOrder;
    if (waterOrder != null && !waterOrder.isTerminal) {
      tasks.add(
        HomeTaskUi(
          target: HomeTaskTarget.drinking,
          title: _waterTaskTitle(waterOrder),
          extra: _waterTaskExtra(waterOrder),
          asset: 'shui_jieshui.png',
        ),
      );
    }
    // 溢出折叠（对齐 legacy：>3 取前 2 + 「更多任务」）。当前三服务最多 3 张，防御性对齐。
    if (tasks.length <= 3) {
      return tasks;
    }
    return [
      ...tasks.take(2),
      HomeTaskUi(
        target: HomeTaskTarget.washer,
        title: '更多任务',
        extra: '还有 ${tasks.length - 2} 个任务',
        asset: 'shui_yifu.png',
      ),
    ];
  }

  /// 洗衣任务标题：按订单 status 派生（对齐 legacy washerTaskTitle）。
  static String _washerTaskTitle(WasherOrderUi order) {
    switch (order.status) {
      case '10':
        return '洗衣待支付';
      case '20':
        return '洗衣已预约';
      case '21':
      case '40':
        return '洗衣进行中';
      case '50':
        return '洗衣已完成';
      default:
        return '洗衣订单';
    }
  }

  /// 洗衣任务副信息：优先剩余/预约时间，否则状态文案（对齐 legacy washerTaskExtra）。
  static String _washerTaskExtra(WasherOrderUi order) {
    if (order.remainTimeSeconds > 0) {
      return '剩余 ${formatSeconds(order.remainTimeSeconds)}';
    }
    if (order.countDownSeconds > 0) {
      return '预约 ${formatSeconds(order.countDownSeconds)}';
    }
    switch (order.status) {
      case '10':
        return '待支付';
      case '20':
        return '待启动';
      default:
        return order.statusText;
    }
  }

  /// 饮水任务标题：按 orderStatus 派生（对齐 legacy waterTaskTitle）。
  static String _waterTaskTitle(WaterOrderUi order) {
    switch (order.orderStatus) {
      case '50':
        return '接水已完成';
      case '0':
        return '等待接水';
      default:
        return '接水中';
    }
  }

  /// 饮水任务副信息：完成显扣费，否则用量/状态（对齐 legacy waterTaskExtra）。
  static String _waterTaskExtra(WaterOrderUi order) {
    if (order.orderStatus == '50') {
      return formatYuanAmount(order.payment);
    }
    if (order.warmWaterMl > 0) {
      return '${order.warmWaterMl}ml';
    }
    return order.statusRemark.isEmpty ? '请按机器按钮' : order.statusRemark;
  }

  ShuiHomeState copyWith({
    RuntimeActionStatus? waterScan,
    RuntimeActionStatus? washerScan,
    BathSystemPreference? bathSystemPreference,
    bool? useSimulatedBackend,
    List<LocalDeviceShortcut>? localDevices,
    String? localDevicesLastRefreshed,
    RuntimeActionStatus? devicesRefresh,
    RuntimeActionStatus? waterOrder,
    List<WaterOrderHistoryUi>? waterHistory,
    // H1 热水字段（委托到 hotwater.copyWith）。
    HotwaterState? hotwater,
    bool? hotwaterRunning,
    RuntimeActionStatus? hotwaterStart,
    RuntimeActionStatus? hotwaterStop,
    List<HotwaterHistoryUi>? hotwaterHistory,
    RuntimeActionStatus? hotwaterHistoryStatus,
    // P2 账号登录字段（委托到 account.copyWith，保持调用方 API 不变）。
    AccountState? account,
    ZhuliSession? zhuli,
    RuntimeActionStatus? hotwaterLogin,
    RuntimeActionStatus? washerLogin,
    RuntimeActionStatus? ujingCaptcha,
    int? ujingCaptchaSentAtMillis,
    UjingAccountUi? ujingAccount,
    bool clearUjingAccount = false,
    // P3 798 字段（委托到 account.copyWith）。
    RuntimeActionStatus? shower798Login,
    RuntimeActionStatus? shower798Captcha,
    int? shower798CaptchaSentAtMillis,
    List<Shower798DeviceUi>? shower798Devices,
    String? currentShower798DeviceId,
    Shower798AccountUi? shower798Account,
    bool clearShower798Account = false,
    String? shower798CaptchaImageBase64,
    bool clearShower798Captcha = false,
    // W1 洗衣字段（委托到 washer.copyWith）。
    WasherState? washer,
    RuntimeActionStatus? washerOrder,
    RuntimeActionStatus? washerPayment,
    List<WasherOrderHistoryUi>? washerHistory,
    WasherProgramUi? washerProgram,
    bool clearWasherProgram = false,
    WasherOrderUi? currentWasherOrder,
    bool clearCurrentWasherOrder = false,
    WasherPaymentUi? currentWasherPayment,
    bool clearWasherPayment = false,
    // 可空字段用显式 clear 标志清空（订单完成时 currentWaterOrder/ready -> null）。
    WaterReadyUi? waterReady,
    bool clearWaterReady = false,
    WaterOrderUi? currentWaterOrder,
    bool clearCurrentWaterOrder = false,
  }) {
    return ShuiHomeState(
      waterScan: waterScan ?? this.waterScan,
      washerScan: washerScan ?? this.washerScan,
      bathSystemPreference: bathSystemPreference ?? this.bathSystemPreference,
      useSimulatedBackend: useSimulatedBackend ?? this.useSimulatedBackend,
      localDevices: localDevices ?? this.localDevices,
      localDevicesLastRefreshed:
          localDevicesLastRefreshed ?? this.localDevicesLastRefreshed,
      devicesRefresh: devicesRefresh ?? this.devicesRefresh,
      waterReady: clearWaterReady ? null : (waterReady ?? this.waterReady),
      currentWaterOrder: clearCurrentWaterOrder
          ? null
          : (currentWaterOrder ?? this.currentWaterOrder),
      waterOrder: waterOrder ?? this.waterOrder,
      waterHistory: waterHistory ?? this.waterHistory,
      hotwater: hotwater ??
          this.hotwater.copyWith(
                running: hotwaterRunning,
                start: hotwaterStart,
                stop: hotwaterStop,
                history: hotwaterHistory,
                historyStatus: hotwaterHistoryStatus,
              ),
      account: account ??
          this.account.copyWith(
                zhuli: zhuli,
                hotwaterLogin: hotwaterLogin,
                washerLogin: washerLogin,
                ujingCaptcha: ujingCaptcha,
                ujingCaptchaSentAtMillis: ujingCaptchaSentAtMillis,
                ujingAccount: ujingAccount,
                clearUjingAccount: clearUjingAccount,
                shower798Login: shower798Login,
                shower798Captcha: shower798Captcha,
                shower798CaptchaSentAtMillis: shower798CaptchaSentAtMillis,
                shower798Devices: shower798Devices,
                currentShower798DeviceId: currentShower798DeviceId,
                shower798Account: shower798Account,
                clearShower798Account: clearShower798Account,
                shower798CaptchaImageBase64: shower798CaptchaImageBase64,
                clearShower798Captcha: clearShower798Captcha,
              ),
      washer: washer ??
          this.washer.copyWith(
                washerOrder: washerOrder,
                washerPayment: washerPayment,
                history: washerHistory,
                program: washerProgram,
                clearProgram: clearWasherProgram,
                currentOrder: currentWasherOrder,
                clearCurrentOrder: clearCurrentWasherOrder,
                payment: currentWasherPayment,
                clearPayment: clearWasherPayment,
              ),
    );
  }
}
