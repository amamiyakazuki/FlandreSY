// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Washer order models (no visual constants). Field names align 1:1 with legacy
// ShuiRuntime.kt WasherProgramUi/WasherModelUi/WasherOrderUi/WasherPaymentUi (101-160).

import 'package:flutter/foundation.dart';

/// 洗衣机扫码后的下单程序信息（对齐 legacy WasherProgramUi）。
@immutable
class WasherProgramUi {
  const WasherProgramUi({
    required this.deviceId,
    required this.deviceNo,
    required this.deviceTypeName,
    required this.storeName,
    required this.status,
    required this.reason,
    required this.createOrderEnabled,
    required this.defaultWashModelId,
    required this.models,
  });

  final String deviceId;
  final String deviceNo;
  final String deviceTypeName;
  final String storeName;
  final String status;
  final String reason;
  final bool createOrderEnabled;
  final int defaultWashModelId;
  final List<WasherModelUi> models;
}

/// 洗衣套餐（对齐 legacy WasherModelUi）。
@immutable
class WasherModelUi {
  const WasherModelUi({
    required this.id,
    required this.name,
    required this.priceFen,
    required this.timeMinutes,
    this.additionGroups = const <WasherAdditionGroupUi>[],
  });

  final int id;
  final String name;
  final int priceFen;
  final int timeMinutes;
  final List<WasherAdditionGroupUi> additionGroups;
}

/// 附加项分组（洗衣液 wp_detergentGearId / 除菌液 wp_disinfectantGearId）。
@immutable
class WasherAdditionGroupUi {
  const WasherAdditionGroupUi({
    required this.key,
    required this.name,
    required this.options,
  });

  final String key;
  final String name;
  final List<WasherAdditionOptionUi> options;
}

/// 附加项档位（对齐 legacy WasherAdditionOptionUi）。
@immutable
class WasherAdditionOptionUi {
  const WasherAdditionOptionUi({
    required this.id,
    required this.name,
    required this.priceFen,
  });

  final int id;
  final String name;
  final int priceFen;
}

/// 当前洗衣订单（对齐 legacy WasherOrderUi）。refreshedAtMillis 用于 W2 live 倒计时。
@immutable
class WasherOrderUi {
  const WasherOrderUi({
    required this.orderId,
    required this.deviceNo,
    required this.statusText,
    required this.payPrice,
    required this.status,
    this.remainTimeSeconds = 0,
    this.countDownSeconds = 0,
    this.refreshedAtMillis = 0,
  });

  final String orderId;
  final String deviceNo;
  final String statusText;
  final String payPrice;

  /// 状态码：10 待支付 / 20 已预约 / 21 启动中 / 40 运行 / 50 完成。
  final String status;
  final int remainTimeSeconds;
  final int countDownSeconds;

  /// 该订单快照的刷新时刻（毫秒）。W2 结合当前时钟算 live 剩余；0 = 未打戳。
  final int refreshedAtMillis;

  /// 终态判定（对齐 legacy isTerminalWasherOrder：status=50 或状态文案含完成/结束/取消）。
  bool get isTerminal =>
      status == '50' ||
      statusText.contains('完成') ||
      statusText.contains('结束') ||
      statusText.contains('取消');

  WasherOrderUi copyWith({
    String? statusText,
    String? status,
    int? remainTimeSeconds,
    int? countDownSeconds,
    int? refreshedAtMillis,
  }) {
    return WasherOrderUi(
      orderId: orderId,
      deviceNo: deviceNo,
      payPrice: payPrice,
      statusText: statusText ?? this.statusText,
      status: status ?? this.status,
      remainTimeSeconds: remainTimeSeconds ?? this.remainTimeSeconds,
      countDownSeconds: countDownSeconds ?? this.countDownSeconds,
      refreshedAtMillis: refreshedAtMillis ?? this.refreshedAtMillis,
    );
  }
}

/// 洗衣订单历史项（对齐 legacy WasherOrderHistoryUi 精简）。
@immutable
class WasherOrderHistoryUi {
  const WasherOrderHistoryUi({
    required this.orderId,
    required this.deviceNo,
    required this.status,
    required this.statusText,
    required this.payPrice,
  });

  final String orderId;
  final String deviceNo;
  final String status;
  final String statusText;
  final String payPrice;
}

/// 支付结果（对齐 legacy WasherPaymentUi）。
@immutable
class WasherPaymentUi {
  const WasherPaymentUi({
    required this.orderId,
    required this.paymentSucceeded,
  });

  final String orderId;
  final bool paymentSucceeded;
}

/// 洗衣水温档位固定价表（分）。key = washTemperatureId，value = 价格分。
/// 用户拍板的固定价表：常温(1)=0 / 30°C(2)=100 / 40°C(3)=150 / 60°C(4)=200。
/// **有意偏离 legacy**（legacy 本地不算水温价，留给服务端 payPrice）——本地全额纳入，
/// 让 UI 预估 == 真机实收，修真机「预估≠实收」的 mismatch。UI 与 fake adapter 共用此表避免漂移。
/// 真机需核对：本表 == 服务端水温定价，否则真实模式仍会 mismatch。
const Map<int, int> kWasherTemperaturePriceFen = <int, int>{
  1: 0,
  2: 100,
  3: 150,
  4: 200,
};

/// 分 → ¥x.xx（对齐 legacy formatFenAmount）。
String formatFenAmount(int priceFen) {
  return '¥${(priceFen / 100.0).toStringAsFixed(2)}';
}

/// 基于刷新时刻计算 live 剩余秒数（对齐 legacy liveRemainSeconds）。
/// rawSeconds<=0 或未打戳（refreshedAtMillis<=0）时返回 rawSeconds 原值。
int liveRemainSeconds(int rawSeconds, int refreshedAtMillis, int nowMillis) {
  if (rawSeconds <= 0 || refreshedAtMillis <= 0) {
    return rawSeconds < 0 ? 0 : rawSeconds;
  }
  final elapsedMs = nowMillis - refreshedAtMillis;
  final elapsed = (elapsedMs < 0 ? 0 : elapsedMs) ~/ 1000;
  final remain = rawSeconds - elapsed;
  return remain < 0 ? 0 : remain;
}

/// 秒 → mm:ss。
String formatSeconds(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final m = (safe ~/ 60).toString().padLeft(2, '0');
  final s = (safe % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
