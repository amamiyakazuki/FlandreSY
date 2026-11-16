import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../../data/washer_history_repository.dart';
import '../../notifications/order_notifier.dart';
import '../models/washer_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

/// 洗衣下单、支付、启停与状态同步。
///
/// 设计要点：
/// - 订单按账号保存，请求结果按订单号写回，账号切换不会串单，也不需要代次校验。
/// - 等待支付宝期间不锁住其他操作；支付结果以服务端订单状态为准，靠刷新确认。
/// - 「付款后自动启动」保存在订单上，任何一次刷新看到「已支付待启动」都会补发一次启动。
/// - 付款后的一段时间内即使 App 在后台（停在支付宝、熄屏）也继续查询，确认到账即启动。
/// - 每个被拒绝的操作都给出提示；任何订单都可以移除本地记录，不会卡死。
mixin WasherActions on ShuiRuntimeBase {
  static const Duration _pollInterval = Duration(seconds: 30);

  /// 支付确认后等待几秒再启动，给服务端同步支付结果的时间。测试可改为 0。
  static Duration autoStartDelay = const Duration(seconds: 3);
  static const int _historyLimit = 100;

  /// 付款后后台跟进的时长与间隔：用户常停在支付宝成功页或直接熄屏，
  /// 不会立刻回到本 App，这段时间内仍需确认到账并启动。测试可调短。
  static Duration paymentWatchWindow = const Duration(minutes: 10);
  static Duration paymentWatchInterval = const Duration(seconds: 5);

  bool _washerScanBusy = false;
  bool _washerActionBusy = false;
  final Map<String, Future<void>> _washerRefreshes = {};
  String? _payingOrderId;
  Timer? _washerPollTimer;
  Timer? _washerFinishTimer;
  int _washerFinishAt = 0;
  Timer? _paymentWatchTimer;
  int _paymentWatchUntil = 0;
  List<WasherReminder>? _syncedReminders;

  /// 当前订单仍在等待「到账后自动启动」，且在跟进时间窗口内。
  bool get _awaitingAutoStart {
    final order = state.currentWasherOrder;
    return ordersReady &&
        order != null &&
        order.autoStart &&
        (order.canPay ||
            order.canStart ||
            order.status == WasherStatus.pending) &&
        clock.nowMillis() < _paymentWatchUntil;
  }

  // ===== 状态提示 =====

  void _orderNotice(String message,
      {RuntimeTaskState status = RuntimeTaskState.success}) {
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerOrder:
                RuntimeActionStatus(state: status, message: message))));
  }

  void _paymentNotice(RuntimeTaskState status, String? message) {
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerPayment:
                RuntimeActionStatus(state: status, message: message))));
  }

  void _fail(String message) =>
      _orderNotice(message, status: RuntimeTaskState.failure);

  Future<void> _handleError(Object error, {bool payment = false}) async {
    if (error is UjingException && error.authInvalid) {
      await handleAuthInvalidation(AuthService.ujing);
      return;
    }
    diagnosticLog.log('washer', '洗衣操作失败 type=${error.runtimeType}');
    final message = error is UjingException ? error.message : '操作失败，请刷新订单后重试';
    if (payment) {
      _paymentNotice(RuntimeTaskState.failure, message);
    } else {
      _fail(message);
    }
  }

  // ===== 本地订单表 =====

  WasherOrderUi? _orderById(String orderId) {
    for (final o in state.washer.orders) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  /// 写入或替换订单（同账号只保留一笔进行中订单）。
  void _putOrder(WasherOrderUi order) {
    final orders = [
      for (final o in state.washer.orders)
        if (o.orderId != order.orderId &&
            o.ownerAccountKey != order.ownerAccountKey)
          o,
      order,
    ];
    emit(state.copyWith(washer: state.washer.copyWith(orders: orders)));
  }

  /// 订单结束：移出进行中列表，写入历史。
  void _finishOrder(WasherOrderUi order) {
    final history = [
      order.toHistory(),
      ...state.washer.history.where((h) => h.orderId != order.orderId),
    ].take(_historyLimit).toList();
    emit(state.copyWith(
        washer: state.washer.copyWith(
            orders: state.washer.orders
                .where((o) => o.orderId != order.orderId)
                .toList(),
            history: history)));
    if (_payingOrderId == order.orderId) _payingOrderId = null;
  }

  Future<void> _saveWasher() async {
    try {
      await washerHistoryRepository.save(WasherSnapshot(
          orders: state.washer.orders, history: state.washer.history));
    } catch (error) {
      diagnosticLog.log('washer', '洗衣订单保存失败 type=${error.runtimeType}');
      _fail('订单已更新，但保存到本机失败；请勿清除数据，稍后会自动重试保存');
    }
  }

  /// 用服务端结果更新本地订单（按订单号写回，与当前登录账号无关）。
  Future<WasherOrderUi?> _applyRemote(WasherOrderUi remote) async {
    final local = _orderById(remote.orderId);
    if (local == null) return null;
    final merged = local.mergeRemote(remote, clock.nowMillis());
    if (merged.status != local.status) {
      diagnosticLog.log('washer',
          '订单状态 ${local.status} → ${merged.status}（${merged.statusText}）');
    }
    if (merged.isTerminal) {
      _finishOrder(merged);
    } else {
      _putOrder(merged);
    }
    await _saveWasher();
    if (_payingOrderId == merged.orderId && !merged.canPay) {
      _payingOrderId = null;
    }
    if (!merged.canPay && state.washer.washerPayment.isBusy) {
      _paymentNotice(RuntimeTaskState.success, '支付成功');
    }
    unawaited(_maybeAutoStart(merged));
    return merged;
  }

  // ===== 生命周期钩子 =====

  @override
  Future<void> adoptUnownedOrders() async {
    await super.adoptUnownedOrders();
    final owner = ujingAccountKey;
    if (owner.isEmpty) return;
    final unowned =
        state.washer.orders.where((o) => o.ownerAccountKey.isEmpty).toList();
    final history = state.washer.history;
    if (unowned.isEmpty && !history.any((h) => h.ownerAccountKey.isEmpty)) {
      return;
    }
    final hasOwn = state.currentWasherOrder != null;
    final orders = <WasherOrderUi>[
      for (final o in state.washer.orders)
        if (o.ownerAccountKey.isNotEmpty) o,
    ];
    final archived = <WasherOrderHistoryUi>[];
    for (final o in unowned) {
      if (!hasOwn && !orders.any((x) => x.ownerAccountKey == owner)) {
        orders.add(o.copyWith(ownerAccountKey: owner));
      } else {
        archived.add(o.copyWith(status: WasherStatus.removed).toHistory());
      }
    }
    emit(state.copyWith(
        washer: state.washer.copyWith(orders: orders, history: [
      ...archived,
      for (final h in history)
        h.ownerAccountKey.isNotEmpty
            ? h
            : WasherOrderHistoryUi(
                orderId: h.orderId,
                deviceNo: h.deviceNo,
                status: h.status,
                statusText: h.statusText,
                payPrice: h.payPrice,
                ownerAccountKey: owner,
                createdAtMillis: h.createdAtMillis),
    ])));
    await _saveWasher();
  }

  @override
  Future<void> refreshActiveOrders() async {
    await super.refreshActiveOrders();
    if (state.currentWasherOrder == null) return;
    await refreshCurrentWasherOrder(quiet: true);
    // 回到 App 时支付宝可能仍未把结果交回（例如停在支付成功页）。
    // 不再等待它：以订单状态为准，仍未支付就允许重新发起。
    final order = state.currentWasherOrder;
    if (_payingOrderId != null && order != null && order.canPay) {
      _payingOrderId = null;
      _paymentNotice(RuntimeTaskState.idle, '如已在支付宝完成付款，稍后会自动确认；未付款可重新支付');
    }
  }

  @override
  void syncOrderPolling() {
    super.syncOrderPolling();
    _syncPaymentWatch();
    _syncReminders();
    final order = state.currentWasherOrder;
    final active = ordersReady && !pollingPaused && order != null;
    if (!active) {
      _washerPollTimer?.cancel();
      _washerPollTimer = null;
      _washerFinishTimer?.cancel();
      _washerFinishTimer = null;
      _washerFinishAt = 0;
      return;
    }
    _washerPollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(refreshCurrentWasherOrder(quiet: true));
    });
    // 运行中：在预计结束后立即查询一次，不必等下一轮轮询。
    final endsAt =
        order.status == WasherStatus.running && order.endsAtMillis > 0
            ? order.endsAtMillis + 5000
            : 0;
    if (endsAt != _washerFinishAt) {
      _washerFinishTimer?.cancel();
      _washerFinishTimer = null;
      _washerFinishAt = endsAt;
      if (endsAt > 0) {
        final delay = endsAt - clock.nowMillis();
        _washerFinishTimer = Timer(
            Duration(milliseconds: delay < 1000 ? 1000 : delay),
            () => unawaited(refreshCurrentWasherOrder(quiet: true)));
      }
    }
  }

  /// 付款跟进不受前后台限制；确认启动、关闭自动启动或超出时间窗口后停止。
  void _syncPaymentWatch() {
    if (isDisposed || !_awaitingAutoStart) {
      if (_paymentWatchTimer != null) {
        _paymentWatchTimer!.cancel();
        _paymentWatchTimer = null;
        unawaited(notifier.setPaymentWatch(false));
      }
      return;
    }
    if (_paymentWatchTimer != null) return;
    unawaited(notifier.setPaymentWatch(true));
    _paymentWatchTimer = Timer.periodic(paymentWatchInterval, (_) {
      if (!_awaitingAutoStart) {
        _syncPaymentWatch();
        return;
      }
      unawaited(refreshCurrentWasherOrder(quiet: true));
    });
  }

  /// 所有账号洗衣中的订单都预约提醒（切换账号不影响已在洗的衣服）。
  /// 只在提醒内容变化时通知系统，避免每次状态更新都重新预约。
  void _syncReminders() {
    if (!ordersReady) return;
    final reminders = [
      for (final o in state.washer.orders)
        if (o.status == WasherStatus.running && o.endsAtMillis > 0)
          WasherReminder(
            orderId: o.orderId,
            deviceNo: o.deviceNo,
            endsAtMillis: o.endsAtMillis,
          ),
    ];
    final last = _syncedReminders;
    if (last != null && _sameReminders(last, reminders)) return;
    _syncedReminders = reminders;
    unawaited(notifier.syncWasherReminders(reminders));
  }

  /// 服务端剩余时间按秒取整，相差一分钟以内的刷新不重新预约。
  static bool _sameReminders(List<WasherReminder> a, List<WasherReminder> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].orderId != b[i].orderId ||
          (a[i].endsAtMillis - b[i].endsAtMillis).abs() > 60 * 1000) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _washerPollTimer?.cancel();
    _washerFinishTimer?.cancel();
    if (_paymentWatchTimer != null) {
      _paymentWatchTimer!.cancel();
      unawaited(notifier.setPaymentWatch(false));
    }
    super.dispose();
  }

  // ===== 扫码 / 下单 =====

  Future<void> scanWasher(String qrCode) async {
    await ready;
    if (ujingAccountKey.isEmpty) {
      emit(state.copyWith(
          washer: state.washer.copyWith(
              washerScan: const RuntimeActionStatus(
                  state: RuntimeTaskState.loginRequired,
                  message: '请先登录 U净账号'))));
      return;
    }
    if (_washerScanBusy) return;
    _washerScanBusy = true;
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerScan: const RuntimeActionStatus(
                state: RuntimeTaskState.loading, message: '正在识别洗衣机'))));
    try {
      final program = await ujing.scanWasher(qrCode);
      emit(state.copyWith(
          washer: state.washer.copyWith(
              program: program,
              washerScan: RuntimeActionStatus(
                  state: program.createOrderEnabled
                      ? RuntimeTaskState.success
                      : RuntimeTaskState.unavailable,
                  message: program.createOrderEnabled
                      ? '洗衣机识别完成'
                      : (program.reason.isEmpty
                          ? '这台洗衣机暂时不能下单'
                          : program.reason)))));
    } catch (error) {
      if (error is UjingException && error.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing);
        return;
      }
      diagnosticLog.log('washer', '洗衣机识别失败 type=${error.runtimeType}');
      emit(state.copyWith(
          washer: state.washer.copyWith(
              washerScan: RuntimeActionStatus(
                  state: RuntimeTaskState.failure,
                  message: error is UjingException
                      ? error.message
                      : '洗衣机识别失败，请重试'))));
    } finally {
      _washerScanBusy = false;
    }
  }

  /// 统一的操作互斥：被拒绝时说明原因，不静默返回。
  Future<bool> _runAction(Future<void> Function() action) async {
    await ready;
    if (_washerActionBusy) {
      _fail('上一个洗衣操作还在处理中，请稍候');
      return false;
    }
    _washerActionBusy = true;
    try {
      await action();
      return true;
    } catch (error) {
      await _handleError(error);
      return false;
    } finally {
      _washerActionBusy = false;
    }
  }

  Future<void> createWasherOrder(
      {required int washModelId,
      required int temperatureId,
      int? detergentGearId,
      int? disinfectantGearId}) async {
    await ready;
    final owner = ujingAccountKey;
    if (owner.isEmpty) {
      _fail('请先登录 U净账号');
      return;
    }
    if (state.currentWasherOrder != null) {
      _fail('你还有一笔洗衣订单未结束，请先处理或移除它');
      return;
    }
    final program = state.washer.program;
    if (program == null || washModelId == 0 || !program.createOrderEnabled) {
      _fail('请先扫描可用的洗衣机并选择套餐');
      return;
    }
    String? createdId;
    await _runAction(() async {
      _orderNotice('正在创建洗衣订单', status: RuntimeTaskState.loading);
      final created = await ujing.createWasherOrder(
          program: program,
          washModelId: washModelId,
          temperatureId: temperatureId,
          detergentGearId: detergentGearId,
          disinfectantGearId: disinfectantGearId);
      // 先记下订单号再查询详情：详情失败也不能丢掉已创建的订单。
      _putOrder(created.copyWith(
          ownerAccountKey: owner, createdAtMillis: clock.nowMillis()));
      emit(state.copyWith(
          washer: state.washer
              .copyWith(washerPayment: const RuntimeActionStatus())));
      await _saveWasher();
      createdId = created.orderId;
      _orderNotice('洗衣订单已创建');
    });
    if (createdId != null) await _refreshOrder(createdId!, quiet: true);
  }

  // ===== 支付 =====

  bool get washerPaymentWaiting => _payingOrderId != null;

  /// 发起支付宝支付。等待支付宝返回期间不锁住其他操作；
  /// 结果以服务端订单状态为准（回到 App、轮询或支付宝返回时都会刷新确认）。
  Future<void> payCurrentWasherOrderWithAlipay(
      bool autoStartAfterPayment) async {
    await ready;
    final order = state.currentWasherOrder;
    if (order == null) {
      _paymentNotice(RuntimeTaskState.failure, '当前没有待支付的洗衣订单');
      return;
    }
    if (!order.canPay) {
      _paymentNotice(
          RuntimeTaskState.failure, '订单当前为「${order.statusLabel}」，不需要支付；请刷新订单');
      return;
    }
    if (_payingOrderId == order.orderId) {
      _paymentNotice(
          RuntimeTaskState.paymentInProgress, '正在等待支付宝返回；如已付款，回到这里会自动确认');
      return;
    }
    // 付款前申请通知权限：用于付款跟进的常驻通知和之后的洗衣提醒。
    await notifier.requestPermission();
    if (autoStartAfterPayment) {
      _paymentWatchUntil =
          clock.nowMillis() + paymentWatchWindow.inMilliseconds;
    }
    _putOrder(order.copyWith(autoStart: autoStartAfterPayment));
    await _saveWasher();
    _payingOrderId = order.orderId;
    _paymentNotice(RuntimeTaskState.paymentInProgress, '正在打开支付宝');
    String resultStatus;
    try {
      resultStatus = await ujing.payWasherOrder(order);
    } catch (error) {
      if (_payingOrderId == order.orderId) _payingOrderId = null;
      await _handleError(error, payment: true);
      return;
    }
    diagnosticLog.log('washer', '支付宝返回 resultStatus=$resultStatus');
    final refreshed = await _refreshOrder(order.orderId, quiet: true);
    if (_payingOrderId == order.orderId) _payingOrderId = null;
    if (refreshed == null || !refreshed.canPay) return; // 已支付或已结束
    _paymentNotice(
        RuntimeTaskState.failure,
        switch (resultStatus) {
          '6001' => '已取消支付，可重新支付',
          '8000' || '6004' => '支付结果确认中，请稍后刷新订单',
          _ => '支付未完成（$resultStatus），可重新支付'
        });
  }

  // ===== 启动 / 停止 / 取消 / 移除 =====

  Future<void> _maybeAutoStart(WasherOrderUi order) async {
    if (!order.autoStart || order.status != WasherStatus.reserved) return;
    // 先清除标记再启动：无论成败都只自动尝试一次，失败后由用户手动启动。
    final current = _orderById(order.orderId);
    if (current == null || !current.autoStart) return;
    _putOrder(current.copyWith(autoStart: false));
    await _saveWasher();
    _orderNotice('支付成功，${autoStartDelay.inSeconds} 秒后自动启动洗衣机',
        status: RuntimeTaskState.loading);
    await Future<void>.delayed(autoStartDelay);
    final latest = _orderById(order.orderId);
    if (latest == null || !latest.canStart) return;
    await _startOrder(latest);
  }

  Future<void> startCurrentWasherOrder() async {
    final order = state.currentWasherOrder;
    if (order == null) {
      _fail('当前没有洗衣订单');
      return;
    }
    if (!order.canStart) {
      _fail(order.status == WasherStatus.starting
          ? '洗衣机正在启动，稍后刷新确认'
          : '订单当前为「${order.statusLabel}」，不能启动；请刷新订单');
      return;
    }
    await _startOrder(order);
  }

  Future<void> _startOrder(WasherOrderUi order) async {
    unawaited(notifier.requestPermission());
    await _runAction(() async {
      _orderNotice('正在启动洗衣机', status: RuntimeTaskState.loading);
      final result = await ujing.startWasherOrder(order);
      final merged = await _applyRemote(result);
      _orderNotice(
          merged?.status == WasherStatus.running ? '洗衣机已启动' : '启动指令已发送，等待设备确认');
    });
  }

  Future<void> stopCurrentWasherOrder() async {
    final order = state.currentWasherOrder;
    if (order == null || !order.canStop) {
      _fail('只有洗衣中的订单可以提前停止');
      return;
    }
    await _runAction(() async {
      _orderNotice('正在提前停止', status: RuntimeTaskState.loading);
      await _applyRemote(await ujing.stopWasherOrder(order));
      _orderNotice('停止指令已发送');
    });
  }

  Future<void> cancelCurrentWasherOrder() async {
    final order = state.currentWasherOrder;
    if (order == null || !order.canCancel) {
      _fail('只有待支付或已支付未启动的订单可以取消');
      return;
    }
    await _runAction(() async {
      _orderNotice('正在取消洗衣订单', status: RuntimeTaskState.loading);
      await ujing.cancelWasherOrder(order);
      _finishOrder(order.copyWith(
          status: WasherStatus.cancelled, statusText: '已取消', autoStart: false));
      await _saveWasher();
      _orderNotice('洗衣订单已取消');
    });
  }

  /// 仅移除本机记录，不向服务端发送任何指令。用于状态异常或无法再操作的订单。
  Future<void> removeCurrentWasherOrderLocally() async {
    await ready;
    final order = state.currentWasherOrder;
    if (order == null) return;
    _finishOrder(
        order.copyWith(status: WasherStatus.removed, autoStart: false));
    await _saveWasher();
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerPayment: const RuntimeActionStatus(),
            washerOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.success, message: '已移除本机订单记录'))));
  }

  // ===== 刷新 =====

  /// 刷新当前账号的洗衣订单。[quiet] 为 true 时只在出错或状态变化时提示。
  Future<void> refreshCurrentWasherOrder({bool quiet = false}) async {
    await ready;
    final order = state.currentWasherOrder;
    if (order == null) {
      if (!quiet) _orderNotice('当前没有进行中的洗衣订单');
      return;
    }
    await _refreshOrder(order.orderId, quiet: quiet);
  }

  Future<WasherOrderUi?> _refreshOrder(String orderId,
      {required bool quiet}) async {
    final pending = _washerRefreshes[orderId];
    if (pending != null) {
      await pending;
      return _orderById(orderId);
    }
    final local = _orderById(orderId);
    if (local == null) return null;
    WasherOrderUi? result;
    final request = () async {
      if (!quiet) _orderNotice('正在刷新洗衣订单', status: RuntimeTaskState.loading);
      try {
        result = await _applyRemote(await ujing.refreshWasherOrder(local));
        final ended = result?.isTerminal ?? true;
        if (!quiet || (ended && result != null)) {
          _orderNotice(ended
              ? '洗衣订单已结束：${result?.statusLabel ?? '已移除'}'
              : '已刷新：${result!.statusLabel}');
        }
      } catch (error) {
        await _handleError(error);
      }
    }();
    _washerRefreshes[orderId] = request;
    try {
      await request;
    } finally {
      _washerRefreshes.remove(orderId);
    }
    return result;
  }

  /// 离开下单页时清除扫码结果；订单与支付状态属于业务状态，不随页面清除。
  void resetWasherTransient() {
    emit(state.copyWith(
        washer: state.washer.copyWith(
            clearProgram: true, washerScan: const RuntimeActionStatus())));
  }
}
