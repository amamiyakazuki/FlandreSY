import '../../data/adapters/ujing_http_adapter.dart';
import '../../data/water_order_repository.dart';
import '../../data/washer_history_repository.dart';
import '../models/washer_order.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

/// 升级恢复只做保全及只读核对，绝不创建/支付/取消/启停设备。
mixin LegacyRecoveryActions on ShuiRuntimeBase {
  Future<void>? _legacyCheck;
  final _recordChecks = <String, Future<bool>>{};
  Future<bool> _checkOnce(String kind, Future<bool> Function() check) {
    final pending = _recordChecks[kind];
    if (pending != null) return pending;
    late final Future<bool> request;
    request = check().whenComplete(() {
      if (identical(_recordChecks[kind], request)) _recordChecks.remove(kind);
    });
    _recordChecks[kind] = request;
    return request;
  }

  @override
  Future<void> prepareLegacyRecords() async {
    if (legacyStorageBlocked) return;
    try {
      final waterOrder = state.currentWaterOrder;
      if (waterOrder != null) {
        final disposition = migration.recordState('water', waterOrder.orderId);
        if (disposition == 'simulated') {
          await water.save(WaterOrderSnapshot(history: state.waterHistory));
          emit(state.copyWith(clearCurrentWaterOrder: true));
        } else if (disposition == 'verified' &&
            waterOrder.ownerAccountKey.isEmpty) {
          final owned = waterOrder.copyWith(
              ownerAccountKey:
                  migration.verifiedOwner('water', waterOrder.orderId));
          await water.save(WaterOrderSnapshot(
              currentOrder: owned, history: state.waterHistory));
          emit(state.copyWith(currentWaterOrder: owned));
        }
      }
      final current = state.washer.currentOrder;
      final history = state.washer.history.map((h) {
        final disposition = migration.recordState('washer', h.orderId);
        if (disposition != 'simulated' && disposition != 'pending') return h;
        if (disposition == 'pending') {
          return WasherOrderHistoryUi(
              orderId: h.orderId,
              deviceNo: h.deviceNo,
              status: h.status,
              statusText: h.statusText,
              payPrice: h.payPrice,
              ownerAccountKey: h.ownerAccountKey,
              needsRecovery: true);
        }
        return WasherOrderHistoryUi(
            orderId: h.orderId,
            deviceNo: h.deviceNo,
            status: h.status,
            statusText: '旧模拟记录（不可操作）',
            payPrice: h.payPrice,
            ownerAccountKey: h.ownerAccountKey,
            needsRecovery: false);
      }).toList();
      var next = current;
      if (current != null &&
          migration.recordState('washer', current.orderId) == 'simulated') {
        next = null;
      } else if (current != null &&
          migration.recordState('washer', current.orderId) == 'verified' &&
          current.ownerAccountKey.isEmpty) {
        next = current.copyWith(
            ownerAccountKey:
                migration.verifiedOwner('washer', current.orderId));
      }
      next ??= WasherHistoryCodec.legacyCandidate(history);
      if (!identical(next, current) ||
          state.washer.history.any((h) =>
              migration.recordState('washer', h.orderId) == 'pending' &&
              !h.needsRecovery) ||
          state.washer.history.any((h) =>
              migration.recordState('washer', h.orderId) == 'simulated' &&
              (h.needsRecovery || h.statusText != '旧模拟记录（不可操作）'))) {
        await washerHistoryRepository.saveSnapshot(
            currentOrder: next, history: history);
        emit(state.copyWith(
            washer: state.washer.copyWith(
                currentOrder: next,
                clearCurrentOrder: next == null,
                history: history)));
      }
      final session = state.hotwater.session;
      if (session != null &&
          migration.recordState('hotwater', session.id) == 'simulated') {
        // 原始会话已备份；isn 留在安全仓库，不接入真实控制，也不删除凭据。
        await settings.saveHotwaterSession(null);
        emit(state.copyWith(
            hotwater:
                state.hotwater.copyWith(clearSession: true, running: false)));
      }
    } catch (_) {
      migration.failure = '旧记录归档保存失败，原记录已保全，请重试。';
    }
  }

  @override
  Future<void> retryLegacyRecovery() {
    if (_legacyCheck != null) return _legacyCheck!;
    late final Future<void> request;
    request = _retryLegacyRecovery().whenComplete(() {
      if (identical(_legacyCheck, request)) _legacyCheck = null;
    });
    _legacyCheck = request;
    return request;
  }

  Future<void> _retryLegacyRecovery() async {
    await ready;
    if (isDisposed ||
        ujingAuthChanging ||
        hotwaterAuthChanging ||
        ujingMutationCount > 0 ||
        hotwaterOperationInFlight ||
        hotwaterAccountWriteCount > 0) {
      return;
    }
    await migration.prepare();
    // 解析损坏的数据需重启后重新读取，不能只清错误标记放行业务。
    if (legacyStorageBlocked) {
      emit(state.copyWith());
      return;
    }
    await prepareLegacyRecords();
    await verifyLegacyWater();
    await verifyLegacyWasher();
    await verifyLegacyHotwater();
    if (!isDisposed) emit(state.copyWith());
  }

  void _waterPending(String message) => emit(state.copyWith(
      waterOrder: RuntimeActionStatus(
          state: RuntimeTaskState.unavailable, message: message)));
  void _washerPending(String message) => emit(state.copyWith(
      washer: state.washer.copyWith(
          washerOrder: RuntimeActionStatus(
              state: RuntimeTaskState.unavailable, message: message))));

  @override
  Future<bool> verifyLegacyWater() => _checkOnce('water', _verifyLegacyWater);

  Future<bool> _verifyLegacyWater() async {
    final order = state.currentWaterOrder;
    if (order == null) return true;
    if (!pendingLegacy('water', order.orderId)) return true;
    if (!legacyServiceReady('ujing') ||
        ujingAuthChanging ||
        state.ujingAccount == null) {
      _waterPending('旧接水记录待核对，请重新登录 U净后重试');
      return false;
    }
    final owner = ujingAccountKey;
    if (order.ownerAccountKey.isNotEmpty && order.ownerAccountKey != owner) {
      _waterPending('旧接水记录属于其他账号，请切回原账号');
      return false;
    }
    final adapter = ujing;
    if (adapter is! UjingHttpAdapter) return false;
    final epoch = ujingAuthEpoch;
    ujingMutationCount++;
    try {
      final verified =
          await adapter.verifyLegacyWaterOrder(order, state.ujingAccount!);
      if (!isUjingRequestCurrent(epoch) ||
          !identical(state.currentWaterOrder, order)) {
        return false;
      }
      final owned = verified.copyWith(ownerAccountKey: owner);
      await water.save(
          WaterOrderSnapshot(currentOrder: owned, history: state.waterHistory));
      await migration.verifyRecord('water', order.orderId, owner);
      if (!isUjingRequestCurrent(epoch)) return false;
      emit(state.copyWith(
          currentWaterOrder: owned,
          waterOrder: const RuntimeActionStatus(
              state: RuntimeTaskState.success, message: '旧接水记录已核对，可刷新状态')));
      return true;
    } catch (_) {
      if (isUjingRequestCurrent(epoch)) {
        _waterPending('旧接水记录尚无法核对，已保留；可重试或在官方 App 核查');
      }
      return false;
    } finally {
      ujingMutationCount--;
    }
  }

  @override
  Future<bool> verifyLegacyWasher() =>
      _checkOnce('washer', _verifyLegacyWasher);

  Future<bool> _verifyLegacyWasher() async {
    final order = state.washer.currentOrder;
    if (order == null) return true;
    if (!pendingLegacy('washer', order.orderId)) return true;
    if (!legacyServiceReady('ujing') ||
        ujingAuthChanging ||
        state.ujingAccount == null) {
      _washerPending('旧洗衣记录待核对，请重新登录 U净后重试');
      return false;
    }
    final owner = ujingAccountKey;
    if (order.ownerAccountKey.isNotEmpty && order.ownerAccountKey != owner) {
      _washerPending('旧洗衣记录属于其他账号，请切回原账号');
      return false;
    }
    final adapter = ujing;
    if (adapter is! UjingHttpAdapter) return false;
    final epoch = ujingAuthEpoch;
    ujingMutationCount++;
    try {
      final verified =
          await adapter.verifyLegacyWasherOrder(order, state.ujingAccount!);
      if (!isUjingRequestCurrent(epoch) ||
          !identical(state.washer.currentOrder, order)) {
        return false;
      }
      final owned = verified.copyWith(ownerAccountKey: owner);
      await washerHistoryRepository.saveSnapshot(
          currentOrder: owned, history: state.washer.history);
      await migration.verifyRecord('washer', order.orderId, owner);
      if (!isUjingRequestCurrent(epoch)) return false;
      emit(state.copyWith(
          washer: state.washer.copyWith(
              currentOrder: owned,
              washerOrder: const RuntimeActionStatus(
                  state: RuntimeTaskState.success,
                  message: '旧洗衣记录已核对，可刷新状态'))));
      return true;
    } catch (_) {
      if (isUjingRequestCurrent(epoch)) {
        _washerPending('旧洗衣记录尚无法核对，已保留；可重试或在官方 App 核查');
      }
      return false;
    } finally {
      ujingMutationCount--;
    }
  }

  @override
  Future<bool> verifyLegacyHotwater() =>
      _checkOnce('hotwater', _verifyLegacyHotwater);

  Future<bool> _verifyLegacyHotwater() async {
    final session = state.hotwater.session;
    if (session == null) return true;
    if (session.system == BathSystemPreference.zhuli &&
        zhuliControlUnavailableReason != null) {
      emit(state.copyWith(
          hotwaterStart: RuntimeActionStatus(
              state: RuntimeTaskState.unavailable,
              message: '$zhuliControlUnavailableReason 旧会话已保留。')));
      return false;
    }
    if (!pendingLegacy('hotwater', session.id)) return true;
    final service =
        session.system == BathSystemPreference.zhuli ? 'zhuli' : 'shower798';
    final account =
        service == 'zhuli' ? state.zhuli.phone : state.shower798Account?.mobile;
    final device = service == 'zhuli'
        ? state.zhuli.deviceCode
        : state.currentShower798DeviceId;
    final epoch = hotwaterAuthEpoch;
    if (!legacyServiceReady(service) ||
        hotwaterAuthChanging ||
        session.simulated ||
        account != session.account ||
        device != session.deviceId) {
      _hotwaterPending();
      return false;
    }
    try {
      if (service == 'zhuli' &&
          (await secure.loadHotwaterIsn(session.id))?.isNotEmpty != true) {
        _hotwaterPending();
        return false;
      }
      if (isDisposed ||
          hotwaterAuthChanging ||
          epoch != hotwaterAuthEpoch ||
          state.hotwater.session?.id != session.id) {
        return false;
      }
      await migration.verifyRecord('hotwater', session.id, session.account);
      emit(state.copyWith(
          hotwaterStart: const RuntimeActionStatus(
              state: RuntimeTaskState.unavailable,
              message: '旧热水记录已核对，可手动结束；尚未发送控制指令')));
      return true;
    } catch (_) {
      _hotwaterPending();
      return false;
    }
  }

  void _hotwaterPending() => emit(state.copyWith(
      hotwater: state.hotwater.copyWith(
          start: const RuntimeActionStatus(
              state: RuntimeTaskState.unavailable,
              message: '旧热水记录待核对，请登录原账号并选择原设备；无法核对时请在官方渠道检查水流'))));
}
