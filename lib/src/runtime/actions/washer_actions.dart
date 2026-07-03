// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Washer order actions (Module W1; refactored in P4 A1 to orchestrate IUjingAdapter).
// The adapter supplies data + IO latency + status transitions; this mixin does validation,
// emit, order-seq / history bookkeeping, refreshedAt stamping (clock), and autoStart timing.

import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../models/washer_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';
import '../washer_state.dart';

mixin WasherActions on ShuiRuntimeBase {
  int _orderSeq = 0;

  /// 扫码识别洗衣机。program 由 adapter 提供。对齐 legacy scanWasher。
  Future<void> scanWasher(String qrCode) async {
    if (state.washer.washerScan.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerScan: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在识别洗衣机',
          ),
        ),
      ),
    );
    final WasherProgramUi program;
    try {
      program = await ujing.scanWasher(qrCode);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerScan: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          program: program,
          washerScan: RuntimeActionStatus(
            state: program.createOrderEnabled
                ? RuntimeTaskState.success
                : RuntimeTaskState.unavailable,
            message: program.createOrderEnabled
                ? '洗衣机识别完成'
                : (program.reason.isEmpty ? '该设备暂不可下单' : program.reason),
          ),
        ),
      ),
    );
  }

  /// 创建洗衣订单（adapter 返回 status='10' 待支付）。对齐 legacy createWasherOrder。
  Future<void> createWasherOrder({
    required int washModelId,
    required int temperatureId,
    int? detergentGearId,
    int? disinfectantGearId,
  }) async {
    if (state.washer.washerOrder.isBusy) {
      return;
    }
    final program = state.washer.program;
    if (program == null || washModelId == 0) {
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: const RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: '请先扫描洗衣机并选择套餐',
            ),
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在创建洗衣订单',
          ),
        ),
      ),
    );
    _orderSeq += 1;
    final WasherOrderUi order;
    try {
      order = await ujing.createWasherOrder(
        program: program,
        washModelId: washModelId,
        temperatureId: temperatureId,
        detergentGearId: detergentGearId,
        disinfectantGearId: disinfectantGearId,
        orderSeq: _orderSeq,
      );
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          currentOrder: order,
          history: _appendHistory(order),
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '洗衣订单已创建',
          ),
        ),
      ),
    );
  }

  /// 支付宝支付（adapter 成功 → status=20；autoStart 则延时自动启动 → 40）。
  /// 对齐 legacy payCurrentWasherOrderWithAlipay。
  Future<void> payCurrentWasherOrderWithAlipay(bool autoStartAfterPayment) async {
    final order = state.washer.currentOrder;
    if (order == null || state.washer.washerPayment.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerPayment: const RuntimeActionStatus(
            state: RuntimeTaskState.paymentInProgress,
            message: '正在启动支付宝支付',
          ),
        ),
      ),
    );
    final WasherOrderUi paid;
    try {
      paid = await ujing.payWasherOrder(order);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerPayment: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          currentOrder: paid,
          payment: WasherPaymentUi(orderId: order.orderId, paymentSucceeded: true),
          history: _appendHistory(paid),
          washerPayment: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: autoStartAfterPayment
                ? '支付宝支付已成功，3 秒后自动启动洗衣机'
                : '支付宝支付已成功，已保留预约，请按需手动启动',
          ),
        ),
      ),
    );
    if (autoStartAfterPayment) {
      await Future<void>.delayed(const Duration(seconds: 3));
      await startCurrentWasherOrder();
    }
  }

  /// 启动洗衣机（adapter → status=40 运行）。对齐 legacy startCurrentWasherOrder。
  Future<void> startCurrentWasherOrder() async {
    final order = state.washer.currentOrder;
    if (order == null || state.washer.washerOrder.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在启动洗衣机',
          ),
        ),
      ),
    );
    // 剩余时间取默认套餐时长（W1 无 live 倒计时，仅展示；每秒刷新在 W2）。
    final minutes = state.washer.program?.models.isNotEmpty ?? false
        ? state.washer.program!.models.first.timeMinutes
        : 35;
    final WasherOrderUi started;
    try {
      started = await ujing.startWasherOrder(order, minutes * 60);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    // refreshedAt 用注入时钟打戳（W2 live 倒计时基准）。
    final running = started.copyWith(refreshedAtMillis: clock.nowMillis());
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          currentOrder: running,
          history: _appendHistory(running),
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '洗衣机已启动',
          ),
        ),
      ),
    );
  }

  /// 提前停止（adapter → status=50）。对齐 legacy stopCurrentWasherOrder。
  Future<void> stopCurrentWasherOrder() async {
    final order = state.washer.currentOrder;
    if (order == null || state.washer.washerOrder.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在提前停止',
          ),
        ),
      ),
    );
    final WasherOrderUi done;
    try {
      done = await ujing.stopWasherOrder(order);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          history: _appendHistory(done),
          clearCurrentOrder: true,
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '洗衣机已提前停止',
          ),
        ),
      ),
    );
  }

  /// 取消订单（真实：经 adapter 作废服务端订单）。对齐 legacy cancelCurrentWasherOrder。
  /// 取代旧「纯本地清 state」假取消——旧实现服务端订单仍活（真机 bug）。
  Future<void> cancelCurrentWasherOrder() async {
    final order = state.washer.currentOrder;
    // 守卫对齐 legacy：下单动作 loading 或支付进行中不允许取消。
    if (order == null ||
        state.washer.washerOrder.isBusy ||
        state.washer.washerPayment.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在取消洗衣订单',
          ),
        ),
      ),
    );
    try {
      await ujing.cancelWasherOrder(order);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    // 服务端已作废 → 历史标「已取消」（对齐 legacy）+ 清当前订单。
    final canceled = order.copyWith(status: 'cancelled', statusText: '已取消');
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          history: _appendHistory(canceled),
          clearCurrentOrder: true,
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '洗衣订单已取消',
          ),
        ),
      ),
    );
  }

  /// 刷新当前订单（adapter：运行中 → 完成）。对齐 legacy refreshCurrentWasherOrder。
  Future<void> refreshCurrentWasherOrder() async {
    final order = state.washer.currentOrder;
    if (order == null || state.washer.washerOrder.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        washer: state.washer.copyWith(
          washerOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在刷新洗衣订单',
          ),
        ),
      ),
    );
    final WasherOrderUi refreshed;
    try {
      refreshed = await ujing.refreshWasherOrder(order);
    } on UjingException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: e.message,
            ),
          ),
        ),
      );
      return;
    }
    if (refreshed.isTerminal) {
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            history: _appendHistory(refreshed),
            clearCurrentOrder: true,
            washerOrder: const RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '洗衣已完成',
            ),
          ),
        ),
      );
    } else {
      // 仍运行：重新打时间戳，保证 live 倒计时以本次刷新为基准。
      final stamped = refreshed.status == '40'
          ? refreshed.copyWith(refreshedAtMillis: clock.nowMillis())
          : null;
      emit(
        state.copyWith(
          washer: state.washer.copyWith(
            currentOrder: stamped,
            washerOrder: const RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '洗衣订单已刷新',
            ),
          ),
        ),
      );
    }
  }

  /// 离开下单页时清理瞬态（program/order/payment + 动作状态）。
  void resetWasherTransient() {
    emit(
      state.copyWith(
        washer: const WasherState(),
      ),
    );
  }

  List<WasherOrderHistoryUi> _appendHistory(WasherOrderUi order) {
    final entry = WasherOrderHistoryUi(
      orderId: order.orderId,
      deviceNo: order.deviceNo,
      status: order.status,
      statusText: order.statusText,
      payPrice: order.payPrice,
    );
    final existing =
        state.washer.history.where((h) => h.orderId != order.orderId).toList();
    return [entry, ...existing];
  }
}
