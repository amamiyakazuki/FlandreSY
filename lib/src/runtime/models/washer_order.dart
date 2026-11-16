// Washer order models (no visual constants). Field names align 1:1 with legacy
// ShuiRuntime.kt WasherProgramUi/WasherModelUi/WasherOrderUi (101-160).

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

/// 洗衣订单状态码的统一解释。服务端只确认过以下几种；其余一律视为「未知」，
/// 页面提供刷新与「移除本地记录」出口，避免订单卡在无法操作的状态。
class WasherStatus {
  const WasherStatus._();

  /// 本地创建后尚未查询到服务端状态。
  static const String pending = 'pending';
  static const String unpaid = '10';
  static const String reserved = '20';
  static const String starting = '21';
  static const String running = '40';
  static const String finished = '50';

  /// 本地取消成功或用户手动移除时写入。
  static const String cancelled = 'cancelled';
  static const String removed = 'removed';

  static const Set<String> active = {
    pending,
    unpaid,
    reserved,
    starting,
    running
  };
  static const Set<String> terminal = {finished, cancelled, removed};

  static String label(String status) => switch (status) {
        pending => '待查询',
        unpaid => '待支付',
        reserved => '已支付待启动',
        starting => '启动中',
        running => '洗衣中',
        finished => '已完成',
        cancelled => '已取消',
        removed => '已移除',
        _ => '状态未知',
      };
}

/// 当前洗衣订单。refreshedAtMillis 用于实时倒计时。
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
    this.ownerAccountKey = '',
    this.createdAtMillis = 0,
    this.autoStart = false,
    this.endsAtMillis = 0,
  });

  /// 实际洗衣通常比程序标称时间多几分钟，预计结束时间统一在服务端剩余时间上
  /// 加这么多。只影响倒计时和提醒，下单页显示的程序时长不变。
  static const Duration finishBuffer = Duration(minutes: 5);

  final String orderId;
  final String deviceNo;

  /// 服务端返回的状态说明，仅用于展示。
  final String statusText;
  final String payPrice;

  /// 状态码，见 [WasherStatus]。
  final String status;
  final int remainTimeSeconds;
  final int countDownSeconds;

  /// 该订单快照的刷新时刻（毫秒）。结合当前时钟算实时剩余；0 = 未打戳。
  final int refreshedAtMillis;

  /// 下单时登录的 U净 账号（手机号）。订单按账号分开保存。
  final String ownerAccountKey;

  /// 本机创建订单的时刻（毫秒）；旧数据为 0。
  final int createdAtMillis;

  /// 付款确认后需要自动启动。持久化保存，App 被杀或支付宝迟迟不返回时，
  /// 下次查询到「已支付待启动」仍会补发启动；发送一次后清除，避免重复启动。
  final bool autoStart;

  /// 预计结束时刻（毫秒）= 服务端剩余时间 + [finishBuffer]；不在洗衣中时为 0。
  /// 服务端剩余归零但仍在洗时保留上一次的值，倒计时继续走完余量。
  final int endsAtMillis;

  /// 洗衣中的实时剩余秒数；不在洗衣中或没有剩余时间时为 0。
  int liveRemainSeconds(int nowMillis) {
    if (status != WasherStatus.running || endsAtMillis <= 0) return 0;
    final ms = endsAtMillis - nowMillis;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  /// 根据服务端剩余秒数计算预计结束时刻；没有剩余时间时沿用 [previous]。
  static int expectedEndsAt(
      String status, int remainSeconds, int atMillis, int previous) {
    if (status != WasherStatus.running) return 0;
    if (remainSeconds <= 0 || atMillis <= 0) return previous;
    return atMillis + remainSeconds * 1000 + finishBuffer.inMilliseconds;
  }

  bool get isTerminal => WasherStatus.terminal.contains(status);
  bool get isUnknown => !isTerminal && !WasherStatus.active.contains(status);

  bool get canPay => status == WasherStatus.unpaid;
  bool get canStart => status == WasherStatus.reserved;
  bool get canStop => status == WasherStatus.running;
  bool get canCancel =>
      status == WasherStatus.unpaid || status == WasherStatus.reserved;

  /// 页面展示用的状态名：已知状态用固定中文，未知状态附带服务端说明。
  String get statusLabel {
    if (!isUnknown) return WasherStatus.label(status);
    final detail = statusText.trim();
    return detail.isEmpty || detail == status ? '状态未知（$status）' : detail;
  }

  WasherOrderUi copyWith({
    String? statusText,
    String? status,
    String? payPrice,
    String? deviceNo,
    int? remainTimeSeconds,
    int? countDownSeconds,
    int? refreshedAtMillis,
    String? ownerAccountKey,
    int? createdAtMillis,
    bool? autoStart,
    int? endsAtMillis,
  }) {
    return WasherOrderUi(
      orderId: orderId,
      deviceNo: deviceNo ?? this.deviceNo,
      payPrice: payPrice ?? this.payPrice,
      statusText: statusText ?? this.statusText,
      status: status ?? this.status,
      remainTimeSeconds: remainTimeSeconds ?? this.remainTimeSeconds,
      countDownSeconds: countDownSeconds ?? this.countDownSeconds,
      refreshedAtMillis: refreshedAtMillis ?? this.refreshedAtMillis,
      ownerAccountKey: ownerAccountKey ?? this.ownerAccountKey,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      autoStart: autoStart ?? this.autoStart,
      endsAtMillis: endsAtMillis ?? this.endsAtMillis,
    );
  }

  /// 用服务端查询结果更新本订单；保留本地才知道的字段。
  WasherOrderUi mergeRemote(WasherOrderUi remote, int nowMillis) => copyWith(
        status: remote.status,
        statusText: remote.statusText,
        payPrice: remote.payPrice.isEmpty ? null : remote.payPrice,
        deviceNo: remote.deviceNo.isEmpty ? null : remote.deviceNo,
        remainTimeSeconds: remote.remainTimeSeconds,
        countDownSeconds: remote.countDownSeconds,
        refreshedAtMillis: nowMillis,
        endsAtMillis: expectedEndsAt(
            remote.status, remote.remainTimeSeconds, nowMillis, endsAtMillis),
      );

  WasherOrderHistoryUi toHistory() => WasherOrderHistoryUi(
        orderId: orderId,
        deviceNo: deviceNo,
        status: status,
        statusText: statusLabel,
        payPrice: payPrice,
        ownerAccountKey: ownerAccountKey,
        createdAtMillis: createdAtMillis,
      );
}

/// 洗衣订单历史项。
@immutable
class WasherOrderHistoryUi {
  const WasherOrderHistoryUi({
    required this.orderId,
    required this.deviceNo,
    required this.status,
    required this.statusText,
    required this.payPrice,
    this.ownerAccountKey = '',
    this.createdAtMillis = 0,
  });

  final String orderId;
  final String deviceNo;
  final String status;
  final String statusText;
  final String payPrice;
  final String ownerAccountKey;
  final int createdAtMillis;
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

/// 秒 → mm:ss。
String formatSeconds(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final m = (safe ~/ 60).toString().padLeft(2, '0');
  final s = (safe % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
