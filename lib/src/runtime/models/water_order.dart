// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Pure data models (no visual constants); UI consumers apply design tokens.

import 'package:flutter/foundation.dart';

/// 扫码后确认的饮水机准备信息。对齐 legacy `WaterReadyUi`
/// （来源 water/serviceSubject/changeWithScan + currentInfo）。
/// 余额单位为「分」（抓包确认：10 元小票 -> balance=1000）。
@immutable
class WaterReadyUi {
  const WaterReadyUi({
    required this.cd,
    required this.serviceSubjectId,
    required this.serviceSubjectName,
    required this.storeId,
    required this.balanceFen,
    this.giftBalanceFen = 0,
  });

  final String cd;
  final String serviceSubjectId;
  final String serviceSubjectName;
  final String storeId;

  /// 小票余额（分）。<=0 视为余额不足，需引导官方 App 充值。
  final int balanceFen;
  final int giftBalanceFen;
}

/// 饮水订单详情。对齐 legacy `WaterOrderUi`（来源 water/createWaterOrder + waterOrderDetail）。
/// 出水/停水由现实机器按钮完成，App 仅创建订单 + 轮询扣费结果。
@immutable
class WaterOrderUi {
  const WaterOrderUi({
    required this.orderId,
    required this.orderNo,
    required this.serviceSubjectName,
    required this.storeName,
    required this.deviceNo,
    required this.orderStatus,
    required this.orderStatusName,
    required this.statusRemark,
    required this.warmWaterMl,
    required this.waterSeconds,
    required this.payment,
    this.payFlag = 0,
  });

  final String orderId;
  final String orderNo;
  final String serviceSubjectName;
  final String storeName;
  final String deviceNo;

  /// 订单状态码：'0' 订单创建 / '50' 取水正常完成（抓包确认）。
  final String orderStatus;
  final String orderStatusName;
  final String statusRemark;

  /// 用水量（毫升），机器上报前为 0。
  final int warmWaterMl;

  /// 用时（秒），机器上报前为 0。
  final int waterSeconds;

  /// 扣费金额（元）。
  final double payment;
  final int payFlag;

  /// 终态判定，对齐 legacy `isTerminalWaterOrder`。
  bool get isTerminal =>
      orderStatus == '50' ||
      orderStatusName.contains('完成') ||
      statusRemark.contains('完成') ||
      statusRemark.contains('结束');
}

/// 饮水完成历史记录。对齐 legacy `WaterOrderHistoryUi`。
@immutable
class WaterOrderHistoryUi {
  const WaterOrderHistoryUi({
    required this.orderId,
    required this.deviceNo,
    required this.status,
    required this.payment,
    required this.warmWaterMl,
    required this.waterSeconds,
    required this.completedAt,
  });

  final String orderId;
  final String deviceNo;
  final String status;
  final double payment;
  final int warmWaterMl;
  final int waterSeconds;
  final String completedAt;
}

/// 金额格式化：分 -> 「¥x.xx」。对齐 legacy `formatFenAmount`。
String formatFenAmount(int priceFen) =>
    '¥${(priceFen / 100.0).toStringAsFixed(2)}';

/// 元金额格式化：「¥x.xx」。对齐 legacy 订单详情扣费展示。
String formatYuanAmount(double yuan) => '¥${yuan.toStringAsFixed(2)}';
