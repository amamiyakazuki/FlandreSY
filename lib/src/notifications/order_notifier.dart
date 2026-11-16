import 'package:flutter/foundation.dart';

/// 一笔洗衣订单需要的提醒：在 [endsAtMillis] 前 5 分钟与预计结束时各提醒一次。
@immutable
class WasherReminder {
  const WasherReminder({
    required this.orderId,
    required this.deviceNo,
    required this.endsAtMillis,
  });

  final String orderId;
  final String deviceNo;
  final int endsAtMillis;

  @override
  bool operator ==(Object other) =>
      other is WasherReminder &&
      other.orderId == orderId &&
      other.deviceNo == deviceNo &&
      other.endsAtMillis == endsAtMillis;

  @override
  int get hashCode => Object.hash(orderId, deviceNo, endsAtMillis);
}

/// 点击通知后要打开的页面。
enum NotificationTarget { washer }

/// 系统通知能力。运行时只依赖这个接口；生产用 [LocalOrderNotifier]，测试用假实现。
abstract class OrderNotifier {
  /// 让洗衣相关通知与 [reminders]（洗衣中的订单）完全一致：
  /// - 通知栏常驻「洗衣中」倒计时，由系统自行倒数，到点自动消失；
  /// - 预约结束前 5 分钟与预计结束时的提醒（系统闹钟触发）。
  /// 新增或时间变化的重新预约，不再需要的取消。
  Future<void> syncWasherReminders(List<WasherReminder> reminders);

  /// 用户点击通知（含点击通知冷启动 App）时发出；只有一个监听者，监听前的事件会缓存。
  Stream<NotificationTarget> get taps;

  /// 付款后等待到账期间开启前台服务（通知栏常驻），防止 App 在后台被系统冻结。
  Future<void> setPaymentWatch(bool active);

  /// 需要时申请通知权限（Android 13+）。拒绝也不影响其他功能。
  Future<void> requestPermission();
}

class NoopOrderNotifier implements OrderNotifier {
  const NoopOrderNotifier();

  @override
  Stream<NotificationTarget> get taps => const Stream.empty();

  @override
  Future<void> syncWasherReminders(List<WasherReminder> reminders) async {}

  @override
  Future<void> setPaymentWatch(bool active) async {}

  @override
  Future<void> requestPermission() async {}
}
