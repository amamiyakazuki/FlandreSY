import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'order_notifier.dart';

/// 基于 flutter_local_notifications 的 Android 实现。其他平台不做任何事。
///
/// - 洗衣提醒用系统闹钟预约（优先精确闹钟），由插件的广播接收器显示，
///   不依赖 App 进程存活；设备重启后由插件重新预约。
/// - 付款跟进用插件自带的前台服务，只在跟进窗口内运行。
class LocalOrderNotifier implements OrderNotifier {
  LocalOrderNotifier({void Function(String message)? log})
      : _log = log ?? _noop;

  static void _noop(String _) {}

  static const String _reminderPayload = 'washer-reminder';
  static const String _runningPayload = 'washer-running';
  static const String _paymentPayload = 'payment-watch';
  static const String _runningChannel = 'washer_running';
  static const int _paymentWatchId = 7001;
  static const Duration preReminder = Duration(minutes: 5);

  final void Function(String message) _log;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;
  bool _paymentWatchActive = false;
  final StreamController<NotificationTarget> _taps =
      StreamController<NotificationTarget>();

  @override
  Stream<NotificationTarget> get taps => _taps.stream;

  void _onTap(String? payload) {
    if (payload == _reminderPayload ||
        payload == _runningPayload ||
        payload == _paymentPayload) {
      _taps.add(NotificationTarget.washer);
    }
  }

  /// 洗衣中常驻通知：系统倒计时，静默，到预计结束时间自动消失。
  static AndroidNotificationDetails _runningDetails(int endsAt, int now) =>
      AndroidNotificationDetails(
        _runningChannel,
        '洗衣进行中',
        channelDescription: '洗衣中常驻通知，显示剩余时间',
        icon: 'ic_stat_washer',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: endsAt,
        usesChronometer: true,
        chronometerCountDown: true,
        timeoutAfter: endsAt - now,
      );

  static const _reminderDetails = AndroidNotificationDetails(
    'washer_reminder',
    '洗衣提醒',
    channelDescription: '洗衣结束前 5 分钟和预计结束时提醒',
    icon: 'ic_stat_washer',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static const _paymentDetails = AndroidNotificationDetails(
    'payment_watch',
    '支付确认',
    channelDescription: '付款后等待到账并自动启动洗衣机',
    icon: 'ic_stat_washer',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    onlyAlertOnce: true,
    showWhen: false,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> _init() => _ready ??= () async {
        if (!Platform.isAndroid) return false;
        try {
          await _plugin.initialize(
              settings: const InitializationSettings(
                  android: AndroidInitializationSettings('ic_stat_washer')),
              onDidReceiveNotificationResponse: (r) => _onTap(r.payload));
          final launch = await _plugin.getNotificationAppLaunchDetails();
          if (launch?.didNotificationLaunchApp == true) {
            _onTap(launch!.notificationResponse?.payload);
          }
          return true;
        } catch (error) {
          _log('通知初始化失败 type=${error.runtimeType}');
          return false;
        }
      }();

  @override
  Future<void> requestPermission() async {
    if (!await _init()) return;
    try {
      final enabled = await _android?.areNotificationsEnabled();
      if (enabled != true) await _android?.requestNotificationsPermission();
    } catch (error) {
      _log('通知权限申请失败 type=${error.runtimeType}');
    }
  }

  @override
  Future<void> syncWasherReminders(List<WasherReminder> reminders) async {
    if (!await _init()) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final desired = <int, ({int at, String title, String body})>{};
      for (final r in reminders) {
        final device = r.deviceNo.isEmpty ? '' : '（设备 ${r.deviceNo}）';
        final pre = r.endsAtMillis - preReminder.inMilliseconds;
        if (pre > now + 30 * 1000) {
          desired[_id(r.orderId, 0)] = (
            at: pre,
            title: '洗衣还剩约 5 分钟',
            body: '可以准备去取衣服了$device',
          );
        }
        if (r.endsAtMillis > now + 10 * 1000) {
          desired[_id(r.orderId, 1)] = (
            at: r.endsAtMillis,
            title: '洗衣应该已经完成',
            body: '记得去取衣服$device',
          );
        }
      }
      await _syncRunning(reminders, now);
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == _reminderPayload && !desired.containsKey(p.id)) {
          await _plugin.cancel(id: p.id);
        }
      }
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      for (final entry in desired.entries) {
        await _android?.zonedSchedule(
          id: entry.key,
          title: entry.value.title,
          body: entry.value.body,
          scheduledDate:
              tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, entry.value.at),
          notificationDetails: _reminderDetails,
          scheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _reminderPayload,
        );
      }
    } catch (error) {
      _log('洗衣提醒预约失败 type=${error.runtimeType}');
    }
  }

  Future<void> _syncRunning(List<WasherReminder> reminders, int now) async {
    final desired = {
      for (final r in reminders)
        if (r.endsAtMillis > now + 10 * 1000) _id(r.orderId, 2): r,
    };
    final active = await _android?.getActiveNotifications() ?? const [];
    for (final n in active) {
      final id = n.id;
      if (n.channelId == _runningChannel &&
          id != null &&
          !desired.containsKey(id)) {
        await _plugin.cancel(id: id);
      }
    }
    for (final entry in desired.entries) {
      final r = entry.value;
      await _android?.show(
        id: entry.key,
        title: '洗衣中',
        body: r.deviceNo.isEmpty ? '点击查看订单' : '设备 ${r.deviceNo} · 点击查看订单',
        notificationDetails: _runningDetails(r.endsAtMillis, now),
        payload: _runningPayload,
      );
    }
  }

  @override
  Future<void> setPaymentWatch(bool active) async {
    if (active == _paymentWatchActive || !await _init()) return;
    _paymentWatchActive = active;
    try {
      if (active) {
        await _android?.startForegroundService(
          id: _paymentWatchId,
          title: '正在确认支付结果',
          body: '到账后会自动启动洗衣机，可以停留在支付宝或熄屏',
          notificationDetails: _paymentDetails,
          payload: _paymentPayload,
          startType: AndroidServiceStartType.startNotSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeDataSync,
          },
        );
      } else {
        await _android?.stopForegroundService();
      }
    } catch (error) {
      // 前台服务启动失败只影响后台保活，查询与回到 App 后的启动仍然有效。
      _log('付款跟进前台服务切换失败 type=${error.runtimeType}');
    }
  }

  /// 跨进程稳定的通知 ID（String.hashCode 不保证跨运行一致）。
  static int _id(String orderId, int slot) {
    var hash = 0x811c9dc5;
    for (final unit in orderId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return (hash & 0x3ffffff0) + 16 + slot;
  }
}
