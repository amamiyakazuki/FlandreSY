// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
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
  });

  final String time;
  final String deviceId;
  final String amount;
  final String status;
  final String orderId;
}
