import 'dart:async';
import '../../data/adapters/ujing_adapter.dart';
import '../../data/washer_history_repository.dart';
import '../models/washer_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin WasherActions on ShuiRuntimeBase {
  int _orderSeq = 0;
  bool _washerMutationBusy = false;
  bool _washerScanBusy = false;
  Future<void>? _washerRefresh;
  int _washerRefreshEpoch = -1;

  bool _washerStorageReady() {
    if (!ujingOrderStorageBlocked) return true;
    _washerMessage('本地订单恢复失败，请先处理存储问题，未创建新订单', failure: true);
    return false;
  }

  void _washerMessage(String message,
      {bool failure = false, bool payment = false}) {
    final status = RuntimeActionStatus(
        state: failure ? RuntimeTaskState.failure : RuntimeTaskState.success,
        message: message);
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerOrder: payment ? null : status,
            washerPayment: payment ? status : null)));
  }

  bool _canUseWasherOrder(WasherOrderUi order) {
    if (canAccessUjingOrder(order.ownerAccountKey)) return true;
    _washerMessage(
        order.ownerAccountKey.isEmpty
            ? '旧订单尚未确认所属账号，请先确认后查询'
            : '该订单属于其他账号，请切回原账号后查询',
        failure: true);
    return false;
  }

  bool _sameWasher(int epoch, WasherOrderUi order) =>
      isUjingRequestCurrent(epoch) &&
      state.washer.currentOrder?.orderId == order.orderId &&
      state.washer.currentOrder?.ownerAccountKey == order.ownerAccountKey;
  bool _retainWasherResult(int epoch, WasherOrderUi order) =>
      canRetainUjingMutationResult(epoch, order.ownerAccountKey) &&
      state.washer.currentOrder?.orderId == order.orderId &&
      state.washer.currentOrder?.ownerAccountKey == order.ownerAccountKey;
  Future<void> _washerError(Object error, int epoch,
      {bool payment = false}) async {
    if (!isUjingRequestCurrent(epoch)) return;
    if (error is UjingException && error.authInvalid) {
      await handleAuthInvalidation(AuthService.ujing, expectedEpoch: epoch);
      return;
    }
    diagnosticLog.log('washer', '订单操作或保存失败 type=${error.runtimeType}');
    _washerMessage(
        error is UjingException
            ? error.message
            : '订单操作或保存失败，已有订单已保留，请刷新重试；暂勿关闭 App',
        failure: true,
        payment: payment);
  }

  Future<void> scanWasher(String qrCode) async {
    await ready;
    if (_washerScanBusy ||
        _washerMutationBusy ||
        !isUjingRequestCurrent(ujingAuthEpoch)) {
      return;
    }
    final epoch = ujingAuthEpoch;
    _washerScanBusy = true;
    ujingMutationCount++;
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerScan: const RuntimeActionStatus(
                state: RuntimeTaskState.loading, message: '正在识别洗衣机'))));
    try {
      final program = await ujing.scanWasher(qrCode);
      if (!isUjingRequestCurrent(epoch)) return;
      emit(state.copyWith(
          washer: state.washer.copyWith(
              program: program,
              washerScan: RuntimeActionStatus(
                  state: program.createOrderEnabled
                      ? RuntimeTaskState.success
                      : RuntimeTaskState.unavailable,
                  message: program.createOrderEnabled
                      ? '洗衣机识别完成'
                      : program.reason))));
    } catch (error) {
      await _washerError(error, epoch);
      if (isUjingRequestCurrent(epoch)) {
        emit(state.copyWith(
            washer: state.washer.copyWith(
                washerScan: const RuntimeActionStatus(
                    state: RuntimeTaskState.failure, message: '洗衣机识别失败，请重试'))));
      }
    } finally {
      _washerScanBusy = false;
      ujingMutationCount--;
    }
  }

  Future<void> createWasherOrder(
      {required int washModelId,
      required int temperatureId,
      int? detergentGearId,
      int? disinfectantGearId}) async {
    await ready;
    if (!_washerStorageReady()) return;
    if (_washerMutationBusy ||
        _washerRefresh != null ||
        !isUjingRequestCurrent(ujingAuthEpoch)) {
      return;
    }
    if (state.washer.currentOrder != null) {
      if (!_canUseWasherOrder(state.washer.currentOrder!)) return;
      _washerMessage('已有洗衣订单，请先处理当前订单', failure: true);
      return;
    }
    final legacy = WasherHistoryCodec.legacyCandidate(state.washer.history);
    if (legacy != null) {
      emit(state.copyWith(washer: state.washer.copyWith(currentOrder: legacy)));
      _canUseWasherOrder(legacy);
      return;
    }
    final program = state.washer.program;
    if (program == null || washModelId == 0 || !program.createOrderEnabled) {
      _washerMessage('请先扫描可用的洗衣机并选择套餐', failure: true);
      return;
    }
    final epoch = ujingAuthEpoch;
    final owner = ujingAccountKey;
    var needsDetail = false;
    if (owner.isEmpty) {
      _washerMessage('请先登录 U净账号', failure: true);
      return;
    }
    _washerMutationBusy = true;
    ujingMutationCount++;
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.loading, message: '正在创建洗衣订单'))));
    try {
      final created = await ujing.createWasherOrder(
          program: program,
          washModelId: washModelId,
          temperatureId: temperatureId,
          detergentGearId: detergentGearId,
          disinfectantGearId: disinfectantGearId,
          orderSeq: ++_orderSeq);
      if (!canRetainUjingMutationResult(epoch, owner)) return;
      final order = created.copyWith(ownerAccountKey: owner);
      // 已创建的订单号必须先留在内存；保存失败时不允许创建替代订单。
      emit(state.copyWith(
          washer:
              state.washer.copyWith(currentOrder: order, clearPayment: true)));
      await _commitWasher(order, epoch, '洗衣订单已创建', retainMutation: true);
      needsDetail = order.status == 'pending' && isUjingRequestCurrent(epoch);
    } catch (error) {
      await _washerError(error, epoch);
    } finally {
      _washerMutationBusy = false;
      ujingMutationCount--;
    }
    if (needsDetail) await refreshCurrentWasherOrder();
  }

  Future<void> _runWasherMutation(
      String message, Future<WasherOrderUi> Function(WasherOrderUi) action,
      {bool payment = false}) async {
    await ready;
    if (!_washerStorageReady()) return;
    final order = state.washer.currentOrder;
    if (order == null ||
        _washerMutationBusy ||
        _washerRefresh != null ||
        !isUjingRequestCurrent(ujingAuthEpoch) ||
        !_canUseWasherOrder(order)) {
      return;
    }
    final epoch = ujingAuthEpoch;
    _washerMutationBusy = true;
    ujingMutationCount++;
    final loading = RuntimeActionStatus(
        state: payment
            ? RuntimeTaskState.paymentInProgress
            : RuntimeTaskState.loading,
        message: message);
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerOrder: payment ? null : loading,
            washerPayment: payment ? loading : null)));
    try {
      final result = await action(order);
      if (!_retainWasherResult(epoch, order)) return;
      if (result.orderId != order.orderId) throw StateError('订单响应不匹配');
      final owned = result.copyWith(
          ownerAccountKey: order.ownerAccountKey,
          refreshedAtMillis: clock.nowMillis());
      await _commitWasher(owned, epoch, payment ? '支付宝支付结果已更新' : '洗衣订单已更新',
          retainMutation: true);
      if (payment && isUjingRequestCurrent(epoch)) {
        final succeeded = ['20', '21', '40', '50'].contains(owned.status);
        emit(state.copyWith(
            washer: state.washer.copyWith(
                payment: WasherPaymentUi(
                    orderId: order.orderId, paymentSucceeded: succeeded),
                washerPayment: RuntimeActionStatus(
                    state: succeeded
                        ? RuntimeTaskState.success
                        : RuntimeTaskState.failure,
                    message: succeeded ? '支付宝支付已成功' : '支付尚未确认，请刷新订单状态'))));
      }
    } catch (error) {
      if (_sameWasher(epoch, order)) {
        await _washerError(error, epoch, payment: payment);
      }
    } finally {
      _washerMutationBusy = false;
      ujingMutationCount--;
    }
  }

  Future<void> payCurrentWasherOrderWithAlipay(
      bool autoStartAfterPayment) async {
    final before = state.washer.currentOrder;
    if (before == null || before.status != '10') return;
    final epoch = ujingAuthEpoch;
    await _runWasherMutation('正在启动支付宝支付', ujing.payWasherOrder, payment: true);
    if (!autoStartAfterPayment ||
        !_sameWasher(epoch, before) ||
        state.washer.payment?.orderId != before.orderId ||
        state.washer.payment?.paymentSucceeded != true ||
        state.washer.currentOrder?.status != '20') {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    if (_sameWasher(epoch, before) &&
        state.washer.currentOrder?.status == '20') {
      await startCurrentWasherOrder();
    }
  }

  Future<void> startCurrentWasherOrder() async {
    if (state.washer.currentOrder?.status != '20') return;
    await _runWasherMutation('正在启动洗衣机', (order) {
      final models = state.washer.program?.models;
      final minutes =
          models != null && models.isNotEmpty ? models.first.timeMinutes : 35;
      return ujing.startWasherOrder(order, minutes * 60);
    });
  }

  Future<void> stopCurrentWasherOrder() async {
    if (state.washer.currentOrder?.status != '40') return;
    await _runWasherMutation('正在提前停止', ujing.stopWasherOrder);
  }

  Future<void> cancelCurrentWasherOrder() async {
    if (!['10', '20'].contains(state.washer.currentOrder?.status)) return;
    await _runWasherMutation('正在取消洗衣订单', (order) async {
      await ujing.cancelWasherOrder(order);
      return order.copyWith(status: 'cancelled', statusText: '已取消');
    });
  }

  @override
  Future<void> refreshCurrentWasherOrder() {
    if (!_washerStorageReady()) return Future.value();
    final pending = _washerRefresh;
    if (pending != null && _washerRefreshEpoch == ujingAuthEpoch) {
      return pending;
    }
    final order = state.washer.currentOrder;
    if (order == null ||
        _washerMutationBusy ||
        !isUjingRequestCurrent(ujingAuthEpoch) ||
        !_canUseWasherOrder(order)) {
      return Future.value();
    }
    late final Future<void> request;
    request = _refreshWasher(order, ujingAuthEpoch).whenComplete(() {
      if (identical(_washerRefresh, request)) _washerRefresh = null;
    });
    _washerRefreshEpoch = ujingAuthEpoch;
    _washerRefresh = request;
    return request;
  }

  Future<void> _refreshWasher(WasherOrderUi order, int epoch) async {
    emit(state.copyWith(
        washer: state.washer.copyWith(
            washerOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.loading, message: '正在刷新洗衣订单'))));
    try {
      final result = await ujing.refreshWasherOrder(order);
      if (!_sameWasher(epoch, order)) return;
      if (result.orderId != order.orderId) throw StateError('订单响应不匹配');
      await _commitWasher(
          result.copyWith(
              ownerAccountKey: order.ownerAccountKey,
              refreshedAtMillis: clock.nowMillis()),
          epoch,
          '洗衣订单已刷新');
    } catch (error) {
      if (_sameWasher(epoch, order)) await _washerError(error, epoch);
    }
  }

  Future<void> _commitWasher(WasherOrderUi order, int epoch, String message,
      {bool retainMutation = false}) async {
    if (!_washerStorageReady()) throw StateError('本地订单恢复失败');
    final history = [
      WasherOrderHistoryUi(
          orderId: order.orderId,
          deviceNo: order.deviceNo,
          status: order.status,
          statusText: order.statusText,
          payPrice: order.payPrice,
          ownerAccountKey: order.ownerAccountKey),
      ...state.washer.history.where((h) =>
          h.orderId != order.orderId ||
          (h.ownerAccountKey.isNotEmpty &&
              h.ownerAccountKey != order.ownerAccountKey))
    ];
    final next =
        order.isTerminal ? WasherHistoryCodec.legacyCandidate(history) : order;
    if (!order.isTerminal) {
      emit(state.copyWith(
          washer:
              state.washer.copyWith(currentOrder: order, history: history)));
    }
    try {
      ujingMutationCount++;
      try {
        await washerHistoryRepository.saveSnapshot(
            currentOrder: next, history: history);
      } finally {
        ujingMutationCount--;
      }
    } catch (error) {
      if (retainMutation &&
          !isUjingRequestCurrent(epoch) &&
          _retainWasherResult(epoch, order)) {
        diagnosticLog.log('washer', '失效后订单保全保存失败 type=${error.runtimeType}');
        emit(state.copyWith(
            washer: state.washer.copyWith(
                washerOrder: const RuntimeActionStatus(
                    state: RuntimeTaskState.loginRequired,
                    message: '登录已失效；订单仅保留在内存，保存失败，请勿关闭 App，重新登录后刷新重试'))));
      }
      rethrow;
    }
    if (!(retainMutation
        ? _retainWasherResult(epoch, order)
        : _sameWasher(epoch, order))) {
      return;
    }
    emit(state.copyWith(
        washer: state.washer.copyWith(
            currentOrder: next,
            clearCurrentOrder: next == null,
            history: history,
            washerOrder: isUjingRequestCurrent(epoch)
                ? RuntimeActionStatus(
                    state: RuntimeTaskState.success,
                    message: next?.ownerAccountKey.isEmpty == true
                        ? '另有旧订单待确认所属账号'
                        : message)
                : null)));
  }

  Future<void> confirmWasherOrderOwner(
      {required String orderId,
      required String accountKey,
      required int epoch}) async {
    if (!_washerStorageReady()) return;
    final order = state.washer.currentOrder;
    if (order == null ||
        order.orderId != orderId ||
        order.ownerAccountKey.isNotEmpty ||
        accountKey.isEmpty ||
        accountKey != ujingAccountKey ||
        epoch != ujingAuthEpoch ||
        _washerMutationBusy ||
        !isUjingRequestCurrent(epoch)) {
      return;
    }
    _washerMutationBusy = true;
    ujingMutationCount++;
    var saved = false;
    try {
      final owned = order.copyWith(ownerAccountKey: accountKey);
      await washerHistoryRepository.saveSnapshot(
          currentOrder: owned, history: state.washer.history);
      if (!_sameWasher(epoch, order)) return;
      emit(state.copyWith(washer: state.washer.copyWith(currentOrder: owned)));
      saved = true;
    } catch (error) {
      await _washerError(error, epoch);
    } finally {
      _washerMutationBusy = false;
      ujingMutationCount--;
    }
    if (saved) await refreshCurrentWasherOrder();
  }

  void resetWasherTransient() {
    // 活动订单与进行中的支付属于业务状态，不随页面销毁。
    emit(state.copyWith(washer: state.washer.copyWith(clearProgram: true)));
  }
}
