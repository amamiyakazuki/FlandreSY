// Hotwater control actions (Module H1; Zhuli part refactored in P4 Z1 to orchestrate IHotwaterAdapter).
// Boundary: Zhuli hot water (start/stop/history) goes through the injected `hotwater` adapter
// (Fake by default, RealZhuliAdapter on device — signed HTTP + BLE). 798 shower (start/stop) stays
// INLINE fake here — it's HTTP not BLE, a separate future adapter. Messages align 1:1 with legacy.

import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../models/account_session.dart';
import '../models/hotwater_history.dart';
import '../models/local_device.dart';
import '../runtime_status.dart';
import '../hotwater_state.dart';
import '../shui_runtime_base.dart';

mixin HotwaterActions on ShuiRuntimeBase {
  bool _sessionOperation = false;
  bool _pollInFlight = false;

  bool _matchesAccount(HotwaterSession session) =>
      session.simulated == simulatedHotwater &&
      (session.system == BathSystemPreference.zhuli
          ? state.zhuli.phone == session.account && !state.hotwaterLogin.isBusy
          : state.shower798Account?.mobile == session.account &&
              !state.shower798Login.isBusy);

  bool _current(HotwaterSession session, int epoch) =>
      !isDisposed &&
      identical(state.hotwater.session, session) &&
      hotwaterAuthEpoch == epoch &&
      _matchesAccount(session);

  void _pending(String message) {
    emit(state.copyWith(
        hotwater: state.hotwater.copyWith(
      running: true,
      start: RuntimeActionStatus(
          state: RuntimeTaskState.unavailable, message: message),
    )));
  }

  Future<void> startHotwater() => _startSession(BathSystemPreference.zhuli);
  Future<void> startShower798() =>
      _startSession(BathSystemPreference.shower798);

  Future<void> _startSession(BathSystemPreference system) async {
    await ready;
    if (isDisposed ||
        _sessionOperation ||
        state.hotwater.session != null ||
        state.hotwaterRunning ||
        state.hotwaterLogin.isBusy ||
        state.shower798Login.isBusy) {
      return;
    }
    final account = system == BathSystemPreference.zhuli
        ? state.zhuli.phone
        : state.shower798Account?.mobile ?? '';
    final device = system == BathSystemPreference.zhuli
        ? state.zhuli.deviceCode
        : state.currentShower798DeviceId;
    if (account.isEmpty || device.isEmpty) {
      _emitStart(RuntimeTaskState.loginRequired, '请先登录并选择设备');
      return;
    }
    _sessionOperation = true;
    _emitStart(RuntimeTaskState.loading, '正在启动热水');
    final epoch = hotwaterAuthEpoch;
    HotwaterSession? session;
    try {
      final baseline = system == BathSystemPreference.zhuli
          ? await hotwater.loadHistory()
          : const <HotwaterHistoryUi>[];
      if (isDisposed || epoch != hotwaterAuthEpoch) return;
      final deviceOrders =
          baseline.where((row) => row.deviceId == device).toList();
      if (deviceOrders.any((row) => row.orderId.isEmpty)) {
        throw const HotwaterException('订单缺少标识，暂时无法建立热水会话');
      }
      session = HotwaterSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        account: account,
        deviceId: device,
        system: system,
        simulated: simulatedHotwater,
        startedAtMillis: clock.nowMillis(),
        baselineOrderIds:
            List.unmodifiable(deviceOrders.map((row) => row.orderId)),
      );
      // 先落盘，再控制设备；意外退出时仍能找到待确认会话。
      await settings.saveHotwaterSession(session);
      if (isDisposed) return;
      emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
        running: true,
        session: session,
        stop: const RuntimeActionStatus(),
      )));
      if (!_current(session, epoch)) return;
      if (system == BathSystemPreference.zhuli) {
        final result = await hotwater.startHotwater(device);
        await secure.saveHotwaterIsn(session.id, result.isn);
      } else {
        await shower798.startShower(device);
      }
      if (!_current(session, epoch)) return;
      emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
        start: const RuntimeActionStatus(
            state: RuntimeTaskState.success, message: '热水使用中'),
      )));
    } catch (error) {
      if (isDisposed) return;
      if (state.hotwater.session != null) {
        _pending('启动结果待确认，请核对订单');
      } else {
        _emitStart(RuntimeTaskState.failure,
            error is HotwaterException ? error.message : '无法保存或查询热水会话，请重试');
      }
    } finally {
      _sessionOperation = false;
      if (!isDisposed && state.hotwater.session != null) startHotwaterPolling();
    }
  }

  Future<void> stopHotwater() => stopActiveHotwater();
  Future<void> stopShower798() => stopActiveHotwater();

  Future<void> stopActiveHotwater() async {
    await ready;
    final session = state.hotwater.session;
    if (isDisposed || session == null || _sessionOperation) return;
    if (!_matchesAccount(session)) {
      _emitStop(RuntimeTaskState.loginRequired, '请登录开启热水时的账号');
      return;
    }
    _sessionOperation = true;
    final epoch = hotwaterAuthEpoch;
    _emitStop(RuntimeTaskState.loading, '正在关闭热水');
    try {
      if (session.system == BathSystemPreference.zhuli) {
        final isn = await secure.loadHotwaterIsn(session.id);
        if (!_current(session, epoch)) return;
        if (isn == null || isn.isEmpty) {
          throw const HotwaterException('关水凭据未恢复，请在原应用或设备上关水');
        }
        await hotwater.stopHotwater(session.deviceId, isn: isn);
      } else {
        await shower798.stopShower(session.deviceId);
      }
      if (_current(session, epoch)) await _finishSession(session, '热水已关闭');
    } catch (error) {
      if (_current(session, epoch)) {
        _emitStop(RuntimeTaskState.failure,
            error is HotwaterException ? error.message : '关水未确认，请重试');
      }
    } finally {
      _sessionOperation = false;
    }
  }

  @override
  Future<void> pollHotwaterStatusOnce() async {
    final session = state.hotwater.session;
    if (isDisposed ||
        pollingPaused ||
        session == null ||
        _sessionOperation ||
        _pollInFlight) {
      return;
    }
    if (!_matchesAccount(session)) {
      _pending('请登录原账号确认热水状态');
      return;
    }
    _pollInFlight = true;
    final epoch = hotwaterAuthEpoch;
    try {
      bool ended;
      if (session.system == BathSystemPreference.zhuli) {
        final orders = await hotwater.loadHistory();
        ended = session.hasNewConsumption(orders);
        if (!_current(session, epoch) || pollingPaused || _sessionOperation) {
          return;
        }
        emit(state.copyWith(hotwaterHistory: orders));
      } else {
        ended = await shower798.isDeviceIdle(session.deviceId);
      }
      if (!_current(session, epoch) || pollingPaused || _sessionOperation) {
        return;
      }
      if (ended) {
        await _finishSession(session, '热水已结束');
      } else {
        _pending('热水状态待确认');
      }
    } catch (_) {
      if (_current(session, epoch) && !_sessionOperation) {
        _pending('订单查询失败，稍后重试');
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _finishSession(HotwaterSession session, String message) async {
    // 磁盘清除成功后才撤掉 UI，失败时下次查询仍可重试。
    await settings.saveHotwaterSession(null);
    if (isDisposed || !identical(state.hotwater.session, session)) return;
    stopHotwaterPolling();
    emit(state.copyWith(
        hotwater: state.hotwater.copyWith(
      running: false,
      clearSession: true,
      start: const RuntimeActionStatus(),
      stop: RuntimeActionStatus(
          state: RuntimeTaskState.success, message: message),
    )));
    if (session.system == BathSystemPreference.shower798) {
      emit(state.copyWith(
        shower798Devices: _mapDeviceStatus(session.deviceId, '空闲'),
        localDevices: _mapLocalStatus(session.deviceId, '空闲'),
      ));
      await devices.saveDevices(state.localDevices);
    }
    await secure.saveHotwaterIsn(session.id, null);
  }

  /// 加载热水历史（经 IHotwaterAdapter）。对齐 legacy loadHotwaterHistory：每次进详情都拉一次
  /// 真实历史并**替换**（非 append）现有列表——P1-FIX：去掉旧「非空即跳过」早返回，那会让
  /// 曾经落盘的假历史（¥1.20/¥2.40）永久冻结、真实数据永不覆盖。失败保留现有（离线可看）。
  Future<void> loadHotwaterHistory() async {
    emit(
      state.copyWith(
        hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在加载热水历史',
        ),
      ),
    );
    final List<HotwaterHistoryUi> history;
    try {
      history = await hotwater.loadHistory();
    } on HotwaterException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.zhuli);
        return;
      }
      emit(
        state.copyWith(
          hotwaterHistoryStatus: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        hotwaterHistory: history,
        hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '热水历史已加载',
        ),
      ),
    );
    // PHIST：拉取到的真实历史落盘，重启可恢复；下次进详情再拉一次覆盖（不再冻结旧值）。
    _persistHistory();
  }

  /// 持久化当前热水历史（fire-and-forget，对齐 devices_actions._persistDevices 范式）。
  void _persistHistory() {
    unawaited(history.saveHistory(state.hotwater.history));
  }

  void _emitStart(RuntimeTaskState taskState, String message) {
    emit(
      state.copyWith(
        hotwaterStart: RuntimeActionStatus(state: taskState, message: message),
      ),
    );
    _scheduleHotwaterErrorClearIfNeeded(taskState);
  }

  void _emitStop(RuntimeTaskState taskState, String message) {
    emit(
      state.copyWith(
        hotwaterStop: RuntimeActionStatus(state: taskState, message: message),
      ),
    );
    _scheduleHotwaterErrorClearIfNeeded(taskState);
  }

  /// 问题2：热水开/关落到「错误态」（failure/loginRequired）时注册 3 秒清理，
  /// 到点把 start/stop 复位为 idle（警告框随即消失，卡片回到「热水待启动」正常态）。
  /// 非错误态（loading/success）不清——处理中/成功状态由后续 emit 覆盖，当前状态需可见。
  void _scheduleHotwaterErrorClearIfNeeded(RuntimeTaskState taskState) {
    final isError = taskState == RuntimeTaskState.failure ||
        taskState == RuntimeTaskState.loginRequired;
    if (!isError) {
      return;
    }
    scheduleHotwaterErrorClear(() {
      // 守卫：仅当到点时「仍处于错误态」才复位——若这 3 秒内用户已重试成功
      // （start=success）或正在处理（loading），保留那个新状态，不误清。
      final startErr =
          state.hotwaterStart.state == RuntimeTaskState.failure ||
              state.hotwaterStart.state == RuntimeTaskState.loginRequired;
      final stopErr = state.hotwaterStop.state == RuntimeTaskState.failure;
      if (!startErr && !stopErr) {
        return;
      }
      emit(
        state.copyWith(
          hotwaterStart: const RuntimeActionStatus(
            state: RuntimeTaskState.idle,
            message: '热水待启动',
          ),
          hotwaterStop: const RuntimeActionStatus(),
        ),
      );
    });
  }

  List<Shower798DeviceUi> _mapDeviceStatus(String deviceId, String status) {
    return state.shower798Devices
        .map(
          (d) => d.id == deviceId
              ? Shower798DeviceUi(id: d.id, name: d.name, lastStatus: status)
              : d,
        )
        .toList();
  }

  List<LocalDeviceShortcut> _mapLocalStatus(String deviceId, String status) {
    return state.localDevices
        .map(
          (d) => d.deviceType == LocalDeviceType.shower798 && d.id == deviceId
              ? d.copyWith(lastStatus: status)
              : d,
        )
        .toList();
  }
}
