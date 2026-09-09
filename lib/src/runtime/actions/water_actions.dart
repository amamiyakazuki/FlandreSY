// DrinkingWater actions (Module B2; refactored in P4 A1 to orchestrate IUjingAdapter).
// The adapter supplies data + IO latency; this mixin does validation + emit + poll bookkeeping.

import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../live_clock.dart';
import '../models/water_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin WaterActions on ShuiRuntimeBase {
  int _waterGeneration = 0;
  bool _showWaterResult = true;

  /// 扫码识别饮水机 → 确认校区/余额 → 创建接水订单（一步式，对齐 legacy
  /// `scanDrinkingWaterAndCreateOrder`）。余额不足时中止并提示充值。
  Future<void> scanDrinkingWaterAndCreateOrder(String cd) async {
    if (state.waterOrder.isBusy) {
      return;
    }
    final generation = ++_waterGeneration;
    _showWaterResult = true;
    emit(
      state.copyWith(
        clearWaterResult: true,
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在识别饮水机',
        ),
        waterOrder: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在创建接水订单',
        ),
      ),
    );

    final WaterPrepareResult result;
    try {
      result = await ujing.scanAndCreateWaterOrder(cd.trim());
    } on UjingException catch (e) {
      if (generation != _waterGeneration) return;
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          waterScan: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }

    if (generation != _waterGeneration) return;
    final ready = result.ready;
    if (result.order == null) {
      emit(
        state.copyWith(
          waterReady: ready,
          clearWaterResult: true,
          waterScan: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '饮水机已识别：${ready.serviceSubjectName}',
          ),
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.unavailable,
            message: '余额不足，请先在官方 App 充值',
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        waterReady: ready,
        clearWaterResult: true,
        currentWaterOrder: result.order,
        waterScan: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '饮水机已识别：${ready.serviceSubjectName}',
        ),
        waterOrder: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '接水订单已创建，请在饮水机上按按钮开始/停止接水',
        ),
      ),
    );
    persistWaterOrders();
    startWaterPolling();
  }

  /// 刷新当前接水订单状态（对齐 legacy `refreshCurrentDrinkingWaterOrder`）。
  /// fake：第一次刷新视为用户已在机器上完成接水 → status=50 + 上报扣费，
  /// 写入历史并清空当前订单（终态）。
  Future<void> refreshCurrentDrinkingWaterOrder() async {
    await _refreshCurrentDrinkingWaterOrder(showLoading: true);
  }

  @override
  Future<void> pollWaterOrderOnce() async {
    await _refreshCurrentDrinkingWaterOrder(showLoading: false);
  }

  bool _waterPollInFlight = false;

  Future<void> _refreshCurrentDrinkingWaterOrder(
      {required bool showLoading}) async {
    if (state.waterOrder.isBusy || state.currentWaterOrder == null) {
      return;
    }
    if (!showLoading && _waterPollInFlight) return;
    if (!showLoading) _waterPollInFlight = true;
    try {
      await _refreshCurrentDrinkingWaterOrderImpl(showLoading: showLoading);
    } finally {
      if (!showLoading) _waterPollInFlight = false;
    }
  }

  Future<void> _refreshCurrentDrinkingWaterOrderImpl(
      {required bool showLoading}) async {
    final generation = _waterGeneration;
    if (showLoading) {
      emit(
        state.copyWith(
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在刷新接水订单',
          ),
        ),
      );
    }

    final current = state.currentWaterOrder!;
    final WaterOrderUi refreshed;
    try {
      refreshed = await ujing.refreshWaterOrder(current);
    } on UjingException catch (e) {
      if (generation != _waterGeneration ||
          state.currentWaterOrder?.orderId != current.orderId) {
        return;
      }
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }

    if (generation != _waterGeneration ||
        state.currentWaterOrder?.orderId != current.orderId) {
      return;
    }

    if (refreshed.isTerminal) {
      final history = [
        ...state.waterHistory.where((h) => h.orderId != refreshed.orderId),
        WaterOrderHistoryUi(
          orderId: refreshed.orderId,
          deviceNo: refreshed.deviceNo,
          status: refreshed.statusRemark,
          payment: refreshed.payment,
          warmWaterMl: refreshed.warmWaterMl,
          waterSeconds: refreshed.waterSeconds,
          // P1-FIX：真实完成时刻（注入 clock），取代硬编码假「刚刚」。
          completedAt: formatClockTime(clock.nowMillis()),
        ),
      ];
      emit(
        state.copyWith(
          clearCurrentWaterOrder: true,
          waterResult: _showWaterResult ? refreshed : null,
          clearWaterResult: !_showWaterResult,
          waterHistory: history,
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message:
                '${refreshed.statusRemark.isEmpty ? refreshed.orderStatusName : refreshed.statusRemark}，已加入订单统计',
          ),
        ),
      );
      persistWaterOrders();
      stopWaterPolling();
      return;
    }

    // 尚未完成（保留分支以便未来多次轮询场景）。
    emit(
      state.copyWith(
        currentWaterOrder: refreshed,
        waterOrder: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '接水订单已刷新：${refreshed.statusRemark}',
        ),
      ),
    );
    persistWaterOrders();
  }

  /// 离开饮水页时清理 ready/banner（不删历史）。
  void resetDrinkingWaterTransient() {
    _showWaterResult = false;
    stopWaterPolling();
    emit(
      state.copyWith(
        clearWaterReady: true,
        clearWaterResult: true,
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.idle,
          message: '扫描饮水机或洗衣机二维码',
        ),
        waterOrder: const RuntimeActionStatus(),
      ),
    );
  }
}
