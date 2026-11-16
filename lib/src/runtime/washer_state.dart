// Washer sub-state (no visual constants). Held by ShuiHomeState.washer.

import 'package:flutter/foundation.dart';

import 'models/washer_order.dart';
import 'runtime_status.dart';

/// 洗衣子状态。进行中的订单按账号分开保存：每个 U净 账号最多一笔，
/// 切换账号不会互相阻塞；当前账号的订单由 [orderFor] 取出。
@immutable
class WasherState {
  const WasherState({
    this.program,
    this.orders = const <WasherOrderUi>[],
    this.history = const <WasherOrderHistoryUi>[],
    this.washerScan = const RuntimeActionStatus(),
    this.washerOrder = const RuntimeActionStatus(),
    this.washerPayment = const RuntimeActionStatus(),
  });

  /// 扫码识别的洗衣程序信息（null = 未扫码）。
  final WasherProgramUi? program;

  /// 所有账号进行中的订单（每个账号至多一笔）。
  final List<WasherOrderUi> orders;

  /// 已结束订单（本地累积，新的在前）。
  final List<WasherOrderHistoryUi> history;

  final RuntimeActionStatus washerScan;

  /// 下单 / 启动 / 停止 / 取消 / 刷新的状态提示。
  final RuntimeActionStatus washerOrder;

  /// 支付状态提示（paymentInProgress 时禁用支付按钮）。
  final RuntimeActionStatus washerPayment;

  WasherOrderUi? orderFor(String account) {
    if (account.isEmpty) return null;
    for (final order in orders) {
      if (order.ownerAccountKey == account) return order;
    }
    return null;
  }

  WasherState copyWith({
    RuntimeActionStatus? washerScan,
    RuntimeActionStatus? washerOrder,
    RuntimeActionStatus? washerPayment,
    List<WasherOrderHistoryUi>? history,
    WasherProgramUi? program,
    bool clearProgram = false,
    List<WasherOrderUi>? orders,
  }) {
    return WasherState(
      program: clearProgram ? null : (program ?? this.program),
      orders: orders ?? this.orders,
      history: history ?? this.history,
      washerScan: washerScan ?? this.washerScan,
      washerOrder: washerOrder ?? this.washerOrder,
      washerPayment: washerPayment ?? this.washerPayment,
    );
  }
}
