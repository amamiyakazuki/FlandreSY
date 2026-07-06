// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// DrinkingWater actions (Module B2; refactored in P4 A1 to orchestrate IUjingAdapter).
// The adapter supplies data + IO latency; this mixin does validation + emit + poll bookkeeping.

import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../live_clock.dart';
import '../models/water_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin WaterActions on ShuiRuntimeBase {
  /// 扫码识别饮水机 → 确认校区/余额 → 创建接水订单（一步式，对齐 legacy
  /// `scanDrinkingWaterAndCreateOrder`）。余额不足时中止并提示充值。
  Future<void> scanDrinkingWaterAndCreateOrder(String cd) async {
    if (state.waterOrder.isBusy) {
      return;
    }
    emit(
      state.copyWith(
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

    final ready = result.ready;
    if (result.order == null) {
      emit(
        state.copyWith(
          waterReady: ready,
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
    // PWATER（问题7）：创建即记录 → 持久化当前订单，重启后订单页饮水分类可恢复。
    persistWaterOrders();
  }

  /// 刷新当前接水订单状态（对齐 legacy `refreshCurrentDrinkingWaterOrder`）。
  /// fake：第一次刷新视为用户已在机器上完成接水 → status=50 + 上报扣费，
  /// 写入历史并清空当前订单（终态）。
  Future<void> refreshCurrentDrinkingWaterOrder() async {
    if (state.waterOrder.isBusy || state.currentWaterOrder == null) {
      return;
    }
    emit(
      state.copyWith(
        waterOrder: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在刷新接水订单',
        ),
      ),
    );

    final current = state.currentWaterOrder!;
    final WaterOrderUi refreshed;
    try {
      refreshed = await ujing.refreshWaterOrder(current);
    } on UjingException catch (e) {
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
          waterHistory: history,
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '接水已完成，已加入订单统计',
          ),
        ),
      );
      // PWATER（问题7）：完成转历史 → 持久化（当前订单已清空，历史含本单花费）。
      persistWaterOrders();
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
    // PWATER（问题7）：刷新后的当前订单状态同步落盘。
    persistWaterOrders();
  }

  /// 离开饮水页时清理 ready/banner（不删历史）。
  void resetDrinkingWaterTransient() {
    emit(
      state.copyWith(
        clearWaterReady: true,
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.idle,
          message: '扫描饮水机或洗衣机二维码',
        ),
        waterOrder: const RuntimeActionStatus(),
      ),
    );
  }
}
