// DrinkingWater actions (Module B2; refactored in P4 A1 to orchestrate IUjingAdapter).
// The adapter supplies data + IO latency; this mixin does validation + emit + poll bookkeeping.

import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../../data/water_order_repository.dart';
import '../live_clock.dart';
import '../models/water_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin WaterActions on ShuiRuntimeBase {
  int _waterGeneration = 0;
  bool _showWaterResult = true;
  bool _waterScanInFlight = false;
  bool _waterCreationPending = false;

  bool _waterStorageReady() {
    if (!ujingOrderStorageBlocked) return true;
    emit(state.copyWith(
        waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '本地订单恢复失败，请先处理存储问题，未创建新订单')));
    return false;
  }

  @override
  Future<void> resumeUjingOrders() async {
    if (isDisposed || ujingAuthChanging) return;
    if (!_waterStorageReady()) return;
    final order = state.currentWaterOrder;
    if (order != null && canAccessUjingOrder(order.ownerAccountKey)) {
      startWaterPolling();
      await pollWaterOrderOnce();
    } else {
      stopWaterPolling();
    }
    await refreshCurrentWasherOrder();
  }

  bool _canUseWaterOrder(WaterOrderUi order) {
    if (canAccessUjingOrder(order.ownerAccountKey)) return true;
    stopWaterPolling();
    emit(state.copyWith(
        waterOrder: RuntimeActionStatus(
      state: RuntimeTaskState.unavailable,
      message: order.ownerAccountKey.isEmpty
          ? '旧订单尚未确认所属账号，请先确认后查询'
          : '该订单属于其他账号，请切回原账号后查询',
    )));
    return false;
  }

  Future<void> confirmWaterOrderOwner(
      {required String orderId,
      required String accountKey,
      required int epoch}) async {
    if (!_waterStorageReady()) return;
    final order = state.currentWaterOrder;
    if (order == null ||
        order.orderId != orderId ||
        order.ownerAccountKey.isNotEmpty ||
        accountKey.isEmpty ||
        accountKey != ujingAccountKey ||
        !isUjingRequestCurrent(epoch) ||
        _waterScanInFlight ||
        _waterRefreshInFlight != null) {
      return;
    }
    _waterScanInFlight = true;
    ujingMutationCount++;
    var saved = false;
    try {
      final owned = order.copyWith(ownerAccountKey: accountKey);
      await water.save(
          WaterOrderSnapshot(currentOrder: owned, history: state.waterHistory));
      if (!isUjingRequestCurrent(epoch) ||
          state.currentWaterOrder?.orderId != orderId) {
        return;
      }
      emit(state.copyWith(currentWaterOrder: owned));
      saved = true;
    } catch (error) {
      if (isUjingRequestCurrent(epoch)) {
        emit(state.copyWith(
            waterOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.failure,
                message: '归属保存失败，旧订单已保留，请重试')));
      }
    } finally {
      _waterScanInFlight = false;
      ujingMutationCount--;
    }
    if (saved) {
      startWaterPolling();
      await refreshCurrentDrinkingWaterOrder();
    }
  }

  /// 扫码识别饮水机 → 确认校区/余额 → 创建接水订单（一步式，对齐 legacy
  /// `scanDrinkingWaterAndCreateOrder`）。余额不足时中止并提示充值。
  Future<void> scanDrinkingWaterAndCreateOrder(String cd) async {
    if (_waterScanInFlight || isDisposed) return;
    _waterScanInFlight = true;
    final epoch = ujingAuthEpoch;
    ujingMutationCount++;
    try {
      await ready;
      if (!_waterStorageReady()) return;
      if (!isUjingRequestCurrent(epoch)) return;
      if (ujingAccountKey.isEmpty) {
        emit(state.copyWith(
            waterOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.failure, message: '请先登录 U净账号')));
        return;
      }
      _showWaterResult = true;
      if (state.currentWaterOrder != null) {
        if (!_canUseWaterOrder(state.currentWaterOrder!)) return;
        await refreshCurrentDrinkingWaterOrder();
        if (!isUjingRequestCurrent(epoch)) return;
        if (isDisposed || state.currentWaterOrder != null) {
          if (!isDisposed &&
              state.waterOrder.state != RuntimeTaskState.failure) {
            emit(state.copyWith(
              waterOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.unavailable,
                message: '已有接水订单尚未结束，请先在饮水机上结束接水后重试',
              ),
            ));
          }
          return;
        }
      }
      await _createWaterOrder(cd);
    } catch (error) {
      diagnosticLog.log('water', '订单创建或保存失败 type=${error.runtimeType}');
      if (isUjingRequestCurrent(epoch)) {
        emit(state.copyWith(
          waterScan: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '接水订单处理失败',
          ),
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: state.currentWaterOrder == null
                ? '接水订单处理失败，请稍后重试'
                : '订单已保留，处理或保存失败，请刷新重试；暂勿关闭 App',
          ),
        ));
      }
    } finally {
      _waterCreationPending = false;
      _waterScanInFlight = false;
      ujingMutationCount--;
    }
  }

  Future<void> _createWaterOrder(String cd) async {
    _waterCreationPending = true;
    final generation = ++_waterGeneration;
    final epoch = ujingAuthEpoch;
    final owner = ujingAccountKey;
    _showWaterResult = true;
    emit(
      state.copyWith(
        clearWaterResult: true,
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在识别饮水机',
        ),
        waterOrder: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在创建接水订单',
        ),
      ),
    );

    final WaterPrepareResult result;
    try {
      result = await ujing.scanAndCreateWaterOrder(cd.trim());
    } on UjingException catch (e) {
      if (generation != _waterGeneration || !isUjingRequestCurrent(epoch)) {
        return;
      }
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing, expectedEpoch: epoch);
        return;
      }
      emit(
        state.copyWith(
          waterScan: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }

    if (generation != _waterGeneration ||
        !canRetainUjingMutationResult(epoch, owner)) {
      return;
    }
    final ready = result.ready;
    if (result.order == null) {
      if (!isUjingRequestCurrent(epoch)) return;
      emit(
        state.copyWith(
          waterReady: ready,
          clearWaterResult: true,
          waterScan: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '饮水机已识别：${ready.serviceSubjectName}',
          ),
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.unavailable,
            message: '余额不足，请先在官方 App 充值',
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        waterReady: ready,
        clearWaterResult: true,
        currentWaterOrder: result.order!.copyWith(ownerAccountKey: owner),
        waterScan: !isUjingRequestCurrent(epoch)
            ? null
            : RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message: '饮水机已识别：${ready.serviceSubjectName}',
              ),
        waterOrder: !isUjingRequestCurrent(epoch)
            ? null
            : const RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message: '接水订单已创建，请在饮水机上按按钮开始/停止接水',
              ),
      ),
    );
    try {
      await persistWaterOrders();
    } catch (error) {
      if (!isUjingRequestCurrent(epoch) &&
          canRetainUjingMutationResult(epoch, owner)) {
        diagnosticLog.log('water', '失效后订单保全保存失败 type=${error.runtimeType}');
        emit(state.copyWith(
            waterOrder: const RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired,
                message: '登录已失效；订单仅保留在内存，保存失败，请勿关闭 App，重新登录后刷新重试')));
      }
      rethrow;
    }
    if (!isUjingRequestCurrent(epoch)) return;
    _waterCreationPending = false;
    startWaterPolling();
    if (result.needsDetailRefresh) {
      await refreshCurrentDrinkingWaterOrder();
    }
  }

  /// 刷新当前接水订单状态（对齐 legacy `refreshCurrentDrinkingWaterOrder`）。
  /// fake：第一次刷新视为用户已在机器上完成接水 → status=50 + 上报扣费，
  /// 写入历史并清空当前订单（终态）。
  Future<void> refreshCurrentDrinkingWaterOrder() async {
    await _refreshCurrentDrinkingWaterOrder(showLoading: true);
  }

  @override
  Future<void> pollWaterOrderOnce() async {
    await _refreshCurrentDrinkingWaterOrder(showLoading: false);
  }

  Future<void>? _waterRefreshInFlight;
  int _waterRefreshEpoch = -1;

  Future<void> _refreshCurrentDrinkingWaterOrder({required bool showLoading}) {
    if (!_waterStorageReady()) return Future.value();
    final pending = _waterRefreshInFlight;
    if (pending != null && _waterRefreshEpoch == ujingAuthEpoch) return pending;
    if (isDisposed ||
        !isUjingRequestCurrent(ujingAuthEpoch) ||
        _waterCreationPending ||
        state.currentWaterOrder == null) {
      return Future.value();
    }
    if (!_canUseWaterOrder(state.currentWaterOrder!)) return Future.value();
    final epoch = ujingAuthEpoch;
    final orderId = state.currentWaterOrder!.orderId;
    late final Future<void> request;
    request = _refreshCurrentDrinkingWaterOrderImpl(showLoading: showLoading)
        .catchError((Object error) {
      diagnosticLog.log('water', '订单查询或保存失败 type=${error.runtimeType}');
      if (isUjingRequestCurrent(epoch) &&
          state.currentWaterOrder?.orderId == orderId) {
        emit(state.copyWith(
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '订单查询或保存失败，已有订单已保留，请刷新重试',
          ),
        ));
      }
    }).whenComplete(() {
      if (identical(_waterRefreshInFlight, request)) {
        _waterRefreshInFlight = null;
      }
    });
    _waterRefreshEpoch = epoch;
    _waterRefreshInFlight = request;
    return request;
  }

  Future<void> _refreshCurrentDrinkingWaterOrderImpl(
      {required bool showLoading}) async {
    final generation = _waterGeneration;
    final epoch = ujingAuthEpoch;
    if (showLoading) {
      emit(
        state.copyWith(
          waterOrder: const RuntimeActionStatus(
            state: RuntimeTaskState.loading,
            message: '正在刷新接水订单',
          ),
        ),
      );
    }

    final current = state.currentWaterOrder!;
    late WaterOrderUi refreshed;
    try {
      refreshed = await ujing.refreshWaterOrder(current);
      if (refreshed.orderId != current.orderId) throw StateError('订单响应不匹配');
      refreshed = refreshed.copyWith(ownerAccountKey: current.ownerAccountKey);
    } on UjingException catch (e) {
      if (!isUjingRequestCurrent(epoch) ||
          generation != _waterGeneration ||
          state.currentWaterOrder?.orderId != current.orderId) {
        return;
      }
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.ujing, expectedEpoch: epoch);
        return;
      }
      emit(
        state.copyWith(
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }

    if (!isUjingRequestCurrent(epoch) ||
        generation != _waterGeneration ||
        state.currentWaterOrder?.orderId != current.orderId) {
      return;
    }

    if (refreshed.isTerminal) {
      final history = [
        ...state.waterHistory.where((h) => h.orderId != refreshed.orderId),
        WaterOrderHistoryUi(
          orderId: refreshed.orderId,
          ownerAccountKey: current.ownerAccountKey,
          deviceNo: refreshed.deviceNo,
          status: refreshed.statusRemark,
          payment: refreshed.payment,
          warmWaterMl: refreshed.warmWaterMl,
          waterSeconds: refreshed.waterSeconds,
          // P1-FIX：真实完成时刻（注入 clock），取代硬编码假「刚刚」。
          completedAt: formatClockTime(clock.nowMillis()),
        ),
      ];
      // 先保存完成记录，再释放单活动订单槽位，避免保存失败后继续下新单。
      ujingMutationCount++;
      try {
        await water.save(WaterOrderSnapshot(history: history));
      } finally {
        ujingMutationCount--;
      }
      if (!isUjingRequestCurrent(epoch) ||
          state.currentWaterOrder?.orderId != current.orderId) {
        return;
      }
      emit(
        state.copyWith(
          clearCurrentWaterOrder: true,
          waterResult: _showWaterResult ? refreshed : null,
          clearWaterResult: !_showWaterResult,
          waterHistory: history,
          waterOrder: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message:
                '${refreshed.statusRemark.isEmpty ? refreshed.orderStatusName : refreshed.statusRemark}，已加入订单统计',
          ),
        ),
      );
      stopWaterPolling();
      return;
    }

    // 尚未完成（保留分支以便未来多次轮询场景）。
    emit(
      state.copyWith(
        currentWaterOrder: refreshed,
        waterOrder: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '接水订单已刷新：${refreshed.statusRemark}',
        ),
      ),
    );
    await persistWaterOrders();
    startWaterPolling();
  }

  /// 离开饮水页时清理 ready/banner（不删历史）。
  void resetDrinkingWaterTransient() {
    _showWaterResult = false;
    emit(
      state.copyWith(
        clearWaterReady: true,
        clearWaterResult: true,
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.idle,
          message: '扫描饮水机或洗衣机二维码',
        ),
        waterOrder: const RuntimeActionStatus(),
      ),
    );
  }
}
