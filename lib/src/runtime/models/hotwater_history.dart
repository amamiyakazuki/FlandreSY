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

  /// [time] 对应的时间戳（毫秒）；无法解析时为 null。
  /// 住理返回「yyyy-MM-dd HH:mm:ss」，也兼容秒 / 毫秒时间戳。
  int? get timeMillis => parseRecordTime(time);
  final String deviceId;
  final String amount;
  final String status;
  final String orderId;
}

/// 解析订单记录里的时间文本；无法解析返回 null。
int? parseRecordTime(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final number = int.tryParse(text);
  if (number != null) {
    if (number > 100000000000) return number; // 毫秒
    if (number > 1000000000) return number * 1000; // 秒
    return null;
  }
  return DateTime.tryParse(text)?.millisecondsSinceEpoch;
}
