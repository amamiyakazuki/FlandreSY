import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../../data/water_order_repository.dart';
import '../live_clock.dart';
import '../models/water_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

/// 饮水：扫码一步建单，出水 / 停水由饮水机按钮完成，App 轮询扣费结果。
/// 订单按账号保存，与洗衣相同；任何订单都可以移除本地记录。
mixin WaterActions on ShuiRuntimeBase {
  static const Duration _pollInterval = Duration(seconds: 10);
  static const int _historyLimit = 100;

  bool _waterScanBusy = false;
  final Map<String, Future<void>> _waterRefreshes = {};
  Timer? _waterPollTimer;

  /// 接水页打开时才把完成结果展示在页面上。
  bool _showWaterResult = false;

  void _waterNotice(String message,
      {RuntimeTaskState status = RuntimeTaskState.success}) {
    emit(state.copyWith(
        waterOrder: RuntimeActionStatus(state: status, message: message)));
  }

  Future<void> _saveWater() async {
    try {
      await water.save(WaterOrderSnapshot(
          orders: state.waterOrders, history: state.waterHistory));
    } catch (error) {
      diagnosticLog.log('water', '饮水订单保存失败 type=${error.runtimeType}');
      _waterNotice('订单已更新，但保存到本机失败；请勿清除数据', status: RuntimeTaskState.failure);
    }
  }

  WaterOrderUi? _waterById(String orderId) {
    for (final o in state.waterOrders) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  void _putWater(WaterOrderUi order) {
    emit(state.copyWith(waterOrders: [
      for (final o in state.waterOrders)
        if (o.orderId != order.orderId &&
            o.ownerAccountKey != order.ownerAccountKey)
          o,
      order,
    ]));
  }

  void _finishWater(WaterOrderUi order, {required String status}) {
    final history = [
      WaterOrderHistoryUi(
        orderId: order.orderId,
        ownerAccountKey: order.ownerAccountKey,
        deviceNo: order.deviceNo,
        status: status,
        payment: order.payment,
        warmWaterMl: order.warmWaterMl,
        waterSeconds: order.waterSeconds,
        completedAt: formatClockTime(clock.nowMillis()),
        completedAtMillis: clock.nowMillis(),
      ),
      ...state.waterHistory.where((h) => h.orderId != order.orderId),
    ].take(_historyLimit).toList();
    emit(state.copyWith(
      waterOrders:
          state.waterOrders.where((o) => o.orderId != order.orderId).toList(),
      waterHistory: history,
    ));
  }

  Future<void> _handleWaterError(Object error) async {
    if (error is UjingException && error.authInvalid) {
      await handleAuthInvalidation(AuthService.ujing);
      return;
    }
    diagnosticLog.log('water', '饮水操作失败 type=${error.runtimeType}');
    _waterNotice(error is UjingException ? error.message : '接水订单处理失败，请稍后重试',
        status: RuntimeTaskState.failure);
  }

  // ===== 生命周期钩子 =====

  @override
  Future<void> adoptUnownedOrders() async {
    await super.adoptUnownedOrders();
    final owner = ujingAccountKey;
    if (owner.isEmpty) return;
    final unownedOrders =
        state.waterOrders.where((o) => o.ownerAccountKey.isEmpty).toList();
    final unownedHistory =
        state.waterHistory.any((h) => h.ownerAccountKey.isEmpty);
    if (unownedOrders.isEmpty && !unownedHistory) return;
    final orders = [
      for (final o in state.waterOrders)
        if (o.ownerAccountKey.isNotEmpty) o,
    ];
    for (final o in unownedOrders) {
      if (!orders.any((x) => x.ownerAccountKey == owner)) {
        orders.add(o.copyWith(ownerAccountKey: owner));
      }
    }
    emit(state.copyWith(waterOrders: orders, waterHistory: [
      for (final h in state.waterHistory)
        h.ownerAccountKey.isNotEmpty
            ? h
            : WaterOrderHistoryUi(
                orderId: h.orderId,
                ownerAccountKey: owner,
                deviceNo: h.deviceNo,
                status: h.status,
                payment: h.payment,
                warmWaterMl: h.warmWaterMl,
                waterSeconds: h.waterSeconds,
                completedAt: h.completedAt,
                completedAtMillis: h.completedAtMillis),
    ]));
    await _saveWater();
  }

  @override
  Future<void> refreshActiveOrders() async {
    await super.refreshActiveOrders();
    if (state.currentWaterOrder != null) {
      await refreshCurrentDrinkingWaterOrder(quiet: true);
    }
  }

  @override
  void syncOrderPolling() {
    super.syncOrderPolling();
    final active =
        ordersReady && !pollingPaused && state.currentWaterOrder != null;
    if (!active) {
      _waterPollTimer?.cancel();
      _waterPollTimer = null;
      return;
    }
    _waterPollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(refreshCurrentDrinkingWaterOrder(quiet: true));
    });
  }

  @override
  void dispose() {
    _waterPollTimer?.cancel();
    super.dispose();
  }

  // ===== 扫码建单 =====

  /// 扫码识别饮水机 → 确认校区 / 余额 → 创建接水订单（一步式）。
  Future<void> scanDrinkingWaterAndCreateOrder(String cd) async {
    await ready;
    _showWaterResult = true;
    final owner = ujingAccountKey;
    if (owner.isEmpty) {
      _waterNotice('请先登录 U净账号', status: RuntimeTaskState.loginRequired);
      return;
    }
    if (_waterScanBusy) {
      _waterNotice('正在处理上一次扫码，请稍候', status: RuntimeTaskState.loading);
      return;
    }
    _waterScanBusy = true;
    try {
      if (state.currentWaterOrder != null) {
        await refreshCurrentDrinkingWaterOrder(quiet: true);
        if (ujingAccountKey != owner) return; // 查询时登录失效
        if (state.currentWaterOrder != null) {
          // 查询失败时保留失败原因，否则说明为什么没有新建订单。
          if (state.waterOrder.state != RuntimeTaskState.failure) {
            _waterNotice('你还有一笔接水订单未结束：请在饮水机上结束接水后刷新，或移除本机记录',
                status: RuntimeTaskState.unavailable);
          }
          return;
        }
      }
      emit(state.copyWith(
        clearWaterResult: true,
        waterScan: const RuntimeActionStatus(
            state: RuntimeTaskState.loading, message: '正在识别饮水机'),
        waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading, message: '正在创建接水订单'),
      ));
      final result = await ujing.scanAndCreateWaterOrder(cd.trim());
      final ready = result.ready;
      final scanned = RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '饮水机已识别：${ready.serviceSubjectName}');
      final order = result.order;
      if (order == null) {
        emit(state.copyWith(
          waterReady: ready,
          waterScan: scanned,
          waterOrder: const RuntimeActionStatus(
              state: RuntimeTaskState.unavailable,
              message: '余额不足，请先在官方 App 充值'),
        ));
        return;
      }
      _putWater(order.copyWith(
          ownerAccountKey: owner, createdAtMillis: clock.nowMillis()));
      emit(state.copyWith(
        waterReady: ready,
        waterScan: scanned,
        waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '接水订单已创建，请在饮水机上按按钮开始/停止接水'),
      ));
      await _saveWater();
      if (result.needsDetailRefresh) {
        await _refreshWater(order.orderId, quiet: true);
      }
    } catch (error) {
      emit(state.copyWith(
          waterScan: const RuntimeActionStatus(
              state: RuntimeTaskState.failure, message: '接水订单处理失败')));
      await _handleWaterError(error);
    } finally {
      _waterScanBusy = false;
    }
  }

  // ===== 刷新 / 移除 =====

  Future<void> refreshCurrentDrinkingWaterOrder({bool quiet = false}) async {
    await ready;
    final order = state.currentWaterOrder;
    if (order == null) {
      if (!quiet) _waterNotice('当前没有进行中的接水订单');
      return;
    }
    await _refreshWater(order.orderId, quiet: quiet);
  }

  Future<void> _refreshWater(String orderId, {required bool quiet}) {
    final pending = _waterRefreshes[orderId];
    if (pending != null) return pending;
    final local = _waterById(orderId);
    if (local == null) return Future.value();
    final request = () async {
      if (!quiet) {
        _waterNotice('正在刷新接水订单', status: RuntimeTaskState.loading);
      }
      try {
        final remote = await ujing.refreshWaterOrder(local);
        final latest = _waterById(orderId);
        if (latest == null) return;
        final merged = remote.copyWith(
            ownerAccountKey: latest.ownerAccountKey,
            createdAtMillis: latest.createdAtMillis);
        if (merged.orderStatus != latest.orderStatus) {
          diagnosticLog.log('water',
              '订单状态 ${latest.orderStatus} → ${merged.orderStatus}（${merged.statusLabel}）');
        }
        if (merged.isTerminal) {
          _finishWater(merged, status: merged.statusLabel);
          emit(state.copyWith(
            waterResult: _showWaterResult ? merged : null,
            clearWaterResult: !_showWaterResult,
          ));
          _waterNotice('${merged.statusLabel}，已加入订单记录');
        } else {
          _putWater(merged);
          if (!quiet) _waterNotice('已刷新：${merged.statusLabel}');
        }
        await _saveWater();
      } catch (error) {
        await _handleWaterError(error);
      }
    }();
    _waterRefreshes[orderId] = request;
    return request.whenComplete(() => _waterRefreshes.remove(orderId));
  }

  /// 仅移除本机记录，不影响饮水机或服务端订单。
  Future<void> removeCurrentWaterOrderLocally() async {
    await ready;
    final order = state.currentWaterOrder;
    if (order == null) return;
    _finishWater(order, status: '已移除本机记录');
    await _saveWater();
    _waterNotice('已移除本机接水订单记录');
  }

  /// 离开饮水页时清理 ready / 结果提示（不删订单与历史）。
  void resetDrinkingWaterTransient() {
    _showWaterResult = false;
    emit(state.copyWith(
      clearWaterReady: true,
      clearWaterResult: true,
      waterScan: const RuntimeActionStatus(
        state: RuntimeTaskState.idle,
        message: '扫描饮水机或洗衣机二维码',
      ),
      waterOrder: const RuntimeActionStatus(),
    ));
  }

  /// 进入饮水页（不扫码，查看已有订单）时调用。
  void enterDrinkingWater() {
    _showWaterResult = true;
    if (state.currentWaterOrder != null) {
      unawaited(refreshCurrentDrinkingWaterOrder(quiet: true));
    }
  }
}
