// Hotwater history model (no visual constants). Field names align 1:1 with legacy
// ShuiRuntime.kt HotwaterHistoryUi (time/deviceId/amount/status/orderId).

import 'package:flutter/foundation.dart';

/// 热水使用历史记录（对齐 legacy HotwaterHistoryUi）。
@immutable
class HotwaterHistoryUi {
  const HotwaterHistoryUi({
    required this.time,
    required this.deviceId,
    required this.amount,
    required this.status,
    required this.orderId,
    this.ownerAccount = '',
  });

  /// 查询时的住理账号；旧版缺失时为空，不自动认领。
  final String ownerAccount;

  HotwaterHistoryUi ownedBy(String account) => HotwaterHistoryUi(
        time: time,
        deviceId: deviceId,
        amount: amount,
        status: status,
        orderId: orderId,
        ownerAccount: account,
      );

  final String time;
  final String deviceId;
  final String amount;
  final String status;
  final String orderId;
}
