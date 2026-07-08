// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Washer sub-state (no visual constants). Extracted like AccountState to keep the aggregate
// ShuiHomeState from bloating (Grok P2 Major pattern). Holds program/order/payment/history.

import 'package:flutter/foundation.dart';

import 'models/washer_order.dart';
import 'runtime_status.dart';

/// 洗衣下单子状态（W1）。不可变 + copyWith。由 [ShuiHomeState.washer] 持有。
@immutable
class WasherState {
  const WasherState({
    this.program,
    this.currentOrder,
    this.payment,
    this.history = const <WasherOrderHistoryUi>[],
    this.washerScan = const RuntimeActionStatus(),
    this.washerOrder = const RuntimeActionStatus(),
    this.washerPayment = const RuntimeActionStatus(),
  });

  /// 扫码识别的洗衣程序信息（null = 未扫码）。
  final WasherProgramUi? program;

  /// 当前订单（创建后存在，终态后清空）。
  final WasherOrderUi? currentOrder;

  /// 最近一次支付结果。
  final WasherPaymentUi? payment;

  /// 订单历史（本地累积）。
  final List<WasherOrderHistoryUi> history;

  /// 扫码动作状态。
  final RuntimeActionStatus washerScan;

  /// 下单/刷新动作状态。
  final RuntimeActionStatus washerOrder;

  /// 支付动作状态（paymentInProgress 时禁用按钮）。
  final RuntimeActionStatus washerPayment;

  WasherState copyWith({
    RuntimeActionStatus? washerScan,
    RuntimeActionStatus? washerOrder,
    RuntimeActionStatus? washerPayment,
    List<WasherOrderHistoryUi>? history,
    WasherProgramUi? program,
    bool clearProgram = false,
    WasherOrderUi? currentOrder,
    bool clearCurrentOrder = false,
    WasherPaymentUi? payment,
    bool clearPayment = false,
  }) {
    return WasherState(
      program: clearProgram ? null : (program ?? this.program),
      currentOrder:
          clearCurrentOrder ? null : (currentOrder ?? this.currentOrder),
      payment: clearPayment ? null : (payment ?? this.payment),
      history: history ?? this.history,
      washerScan: washerScan ?? this.washerScan,
      washerOrder: washerOrder ?? this.washerOrder,
      washerPayment: washerPayment ?? this.washerPayment,
    );
  }
}
