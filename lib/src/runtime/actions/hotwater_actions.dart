// 手动热水控制：命令串行；订单查询只更新记录；恢复显示使用 40 分钟窗口。

import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../../data/adapters/shower798_adapter.dart';
import '../models/account_session.dart';
import '../models/local_device.dart';
import '../runtime_status.dart';
import '../hotwater_state.dart';
import '../shui_runtime_base.dart';

mixin HotwaterActions on ShuiRuntimeBase {
  bool _sessionOperation = false;
  Future<void> _operationTail = Future<void>.value();
  String? _lastQueuedKey;
  Future<void>? _lastControlFuture;
  int _controlGeneration = 0;
  Future<void>? _historyRequest;
  Object? _historyRequestKey;

  String _accountFor(BathSystemPreference system) =>
      system == BathSystemPreference.zhuli
          ? state.zhuli.phone
          : state.shower798Account?.mobile ?? '';

  String _deviceFor(BathSystemPreference system) {
    final session = state.hotwater.session;
    if (session?.system == system && _matchesAccount(session!)) {
      return session.deviceId;
    }
    return system == BathSystemPreference.zhuli
        ? state.zhuli.deviceCode
        : state.currentShower798DeviceId;
  }

  /// 连续重复点击合并，开/关及恢复/本地清理按顺序完成。
  Future<void> _enqueue(Future<void> Function() action, {String? key}) {
    if (key != null && key == _lastQueuedKey && _lastControlFuture != null) {
      diagnosticLog.log('hotwater', '合并重复在途控制');
      return _lastControlFuture!;
    }
    if (key != null) _lastQueuedKey = key;
    late final Future<void> operation;
    operation = _operationTail.then((_) async {
      if (isDisposed) return;
      _sessionOperation = true;
      final operationEpoch = hotwaterAuthEpoch;
      _controlGeneration++;
      if (state.hotwater.historyStatus.isBusy) {
        emit(
            state.copyWith(hotwaterHistoryStatus: const RuntimeActionStatus()));
      }
      try {
        await action();
      } catch (error) {
        if (!isDisposed) {
          diagnosticLog.log('hotwater', '热水操作失败 type=${error.runtimeType}');
          _emitStart(RuntimeTaskState.failure, '热水操作失败，请重试');
        }
      } finally {
        if (!isDisposed &&
            (state.hotwaterStart.isBusy || state.hotwaterStop.isBusy)) {
          final status = RuntimeActionStatus(
            state: operationEpoch != hotwaterAuthEpoch
                ? RuntimeTaskState.loginRequired
                : RuntimeTaskState.failure,
            message: operationEpoch != hotwaterAuthEpoch
                ? '登录状态已变化，请重新登录后操作'
                : '热水操作未完成，请重试',
          );
          emit(state.copyWith(
            hotwaterStart: state.hotwaterStart.isBusy ? status : null,
            hotwaterStop: state.hotwaterStop.isBusy ? status : null,
          ));
        }
        _sessionOperation = false;
        if (identical(_lastControlFuture, operation)) {
          _lastQueuedKey = null;
          _lastControlFuture = null;
        }
      }
    });
    _operationTail = operation;
    if (key != null) _lastControlFuture = operation;
    return operation;
  }

  Future<void> _queueControl(
      BathSystemPreference? requestedSystem, bool start) async {
    await ready;
    if (isDisposed) return;
    final system = requestedSystem ?? state.hotwaterControlSystem;
    if (hotwaterAuthChanging) {
      (start ? _emitStart : _emitStop)(
          RuntimeTaskState.unavailable, '正在更新登录状态，请稍后重试');
      return;
    }
    if (system == BathSystemPreference.none) {
      (start ? _emitStart : _emitStop)(
          RuntimeTaskState.loginRequired, '请先选择洗浴系统');
      return;
    }
    final account = _accountFor(system);
    final device = _deviceFor(system);
    final epoch = hotwaterAuthEpoch;
    await _enqueue(() async {
      if (hotwaterAuthChanging ||
          epoch != hotwaterAuthEpoch ||
          account != _accountFor(system) ||
          device != _deviceFor(system)) {
        (start ? _emitStart : _emitStop)(
            RuntimeTaskState.failure, '账号或设备已变化，请重新操作');
        return;
      }
      if (start) {
        await _startSession(system, device);
      } else {
        await _stopSession(system, device);
      }
    }, key: '$start:${system.name}:$epoch:$account:$device');
  }

  @override
  Future<void> resumeHotwaterSession() => _enqueue(() async {
        final session = state.hotwater.session;
        if (session == null) return;
        final expired = session.hasExceededRestoreWindow(clock.nowMillis());
        if (expired || !session.mayHaveStarted) {
          final cleared = await clearHotwaterSessionLocally(
            expected: session,
            resultState: RuntimeTaskState.idle,
            message: '热水待启动',
          );
          if (cleared &&
              expired &&
              session.system == BathSystemPreference.zhuli &&
              _matchesAccount(session)) {
            unawaited(loadHotwaterHistory());
          }
          return;
        }
        emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
            running: true,
            start: const RuntimeActionStatus(
                state: RuntimeTaskState.success, message: '热水使用中'),
            stop: const RuntimeActionStatus(),
          ),
        ));
      });

  bool _matchesAccount(HotwaterSession session) =>
      session.simulated == simulatedHotwater &&
      (session.system == BathSystemPreference.zhuli
          ? state.zhuli.phone == session.account && !state.hotwaterLogin.isBusy
          : state.shower798Account?.mobile == session.account &&
              !state.shower798Login.isBusy);

  bool _current(HotwaterSession session, int epoch) =>
      !isDisposed &&
      state.hotwater.session?.id == session.id &&
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

  Future<void> startHotwater() =>
      _queueControl(BathSystemPreference.zhuli, true);
  Future<void> startShower798() =>
      _queueControl(BathSystemPreference.shower798, true);

  Future<void> _startSession(BathSystemPreference system, String device) async {
    if (state.hotwaterLogin.isBusy || state.shower798Login.isBusy) {
      _emitStart(RuntimeTaskState.loginRequired, '正在登录，请稍后重试');
      return;
    }
    final account = _accountFor(system);
    if (account.isEmpty || device.isEmpty) {
      _emitStart(RuntimeTaskState.loginRequired, '请先登录并选择设备');
      return;
    }
    final previous = state.hotwater;
    final existing = previous.session;
    if (existing != null &&
        existing.system == system &&
        existing.account == account &&
        existing.deviceId == device &&
        existing.mayHaveStarted &&
        _matchesAccount(existing)) {
      diagnosticLog.log('hotwater', '忽略重复启动 phase=${existing.phase.name}');
      _emitStart(
        existing.phase == HotwaterSessionPhase.active
            ? RuntimeTaskState.success
            : RuntimeTaskState.unavailable,
        existing.phase == HotwaterSessionPhase.active
            ? '热水使用中'
            : '上次启动结果待确认，未重复发送；请核对水流，可点击结束热水',
      );
      return;
    }
    _emitStart(RuntimeTaskState.loading, '正在启动热水');
    final epoch = hotwaterAuthEpoch;
    HotwaterSession? session;
    var commandSent = false;
    try {
      final initialSession = HotwaterSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        account: account,
        deviceId: device,
        system: system,
        simulated: simulatedHotwater,
        startedAtMillis: clock.nowMillis(),
        baselineOrderIds: const [],
      );
      session = initialSession;
      // 先落盘，再控制设备；意外退出时仍能找到待确认会话。
      await settings.saveHotwaterSession(initialSession);
      if (isDisposed) return;
      emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
        running: previous.running,
        session: initialSession,
        stop: const RuntimeActionStatus(),
      )));
      if (!_current(initialSession, epoch)) return;
      if (system == BathSystemPreference.zhuli) {
        final result = await hotwater.startHotwater(
          device,
          onProgress: (progress) async {
            final current = session;
            if (current == null || !_current(current, epoch)) {
              throw const HotwaterException('热水启动已取消');
            }
            if (progress.isn.isNotEmpty) {
              await secure.saveHotwaterIsn(current.id, progress.isn);
            }
            if (progress.stage == HotwaterStartStage.commandSent) {
              commandSent = true;
            }
            final updated = current.copyWith(
              startedAtMillis: progress.stage == HotwaterStartStage.commandSent
                  ? clock.nowMillis()
                  : null,
              phase: commandSent
                  ? HotwaterSessionPhase.uncertain
                  : HotwaterSessionPhase.starting,
              orderId:
                  progress.orderId.isEmpty ? current.orderId : progress.orderId,
            );
            if (commandSent) {
              session = updated;
              emit(state.copyWith(
                  hotwater: state.hotwater.copyWith(
                running: true,
                session: updated,
              )));
            }
            await settings.saveHotwaterSession(updated);
            if (!_current(current, epoch)) {
              throw const HotwaterException('热水启动已取消');
            }
            session = updated;
            emit(state.copyWith(
              hotwater: state.hotwater.copyWith(
                running: updated.mayHaveStarted || previous.running,
                session: updated,
                start: RuntimeActionStatus(
                  state: RuntimeTaskState.loading,
                  message: commandSent ? '启动指令已发送，正在确认' : '正在准备热水订单',
                ),
              ),
            ));
          },
        );
        final current = session;
        if (current == null) {
          throw const HotwaterException('热水启动会话已丢失');
        }
        await secure.saveHotwaterIsn(current.id, result.isn);
        session = current.copyWith(
          phase: HotwaterSessionPhase.active,
          orderId: result.orderId.isEmpty ? current.orderId : result.orderId,
        );
      } else {
        final current = session;
        final uncertain = current.copyWith(
          phase: HotwaterSessionPhase.uncertain,
          startedAtMillis: clock.nowMillis(),
        );
        session = uncertain;
        commandSent = true;
        await settings.saveHotwaterSession(uncertain);
        if (!_current(uncertain, epoch)) return;
        emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
            running: true,
            session: uncertain,
            start: const RuntimeActionStatus(
              state: RuntimeTaskState.loading,
              message: '启动请求已发送，正在确认',
            ),
          ),
        ));
        await shower798.startShower(device);
        final started = session;
        session = started.copyWith(phase: HotwaterSessionPhase.active);
      }
      final active = session;
      if (active == null || !_current(active, epoch)) return;
      await settings.saveHotwaterSession(active);
      if (!_current(active, epoch)) return;
      emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
        running: true,
        session: active,
        start: const RuntimeActionStatus(
            state: RuntimeTaskState.success, message: '热水使用中'),
      )));
    } catch (error) {
      if (isDisposed || epoch != hotwaterAuthEpoch) return;
      final current = session;
      if (current != null && commandSent && _current(current, epoch)) {
        final uncertain = current.copyWith(
          phase: HotwaterSessionPhase.uncertain,
        );
        session = uncertain;
        emit(state.copyWith(
            hotwater: state.hotwater.copyWith(
          running: true,
          session: uncertain,
        )));
        try {
          await settings.saveHotwaterSession(uncertain);
        } catch (_) {
          _emitStart(RuntimeTaskState.unavailable,
              '启动结果未确认且保存失败，请勿关闭 App；未重复发送，可点击结束热水');
          return;
        }
        if (!_current(current, epoch)) return;
        session = uncertain;
        emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
            running: true,
            session: uncertain,
          ),
        ));
        _pending('启动指令已发送但结果待确认，请核对设备');
      } else if (current != null && _current(current, epoch)) {
        final message =
            error is HotwaterException ? error.message : '启动热水失败，请重试';
        if (previous.session != null) {
          // 再次开始在发送前失败，不丢掉前一次已开水状态和凭据。
          await settings.saveHotwaterSession(previous.session);
          if (!_current(current, epoch)) return;
          emit(state.copyWith(hotwater: previous));
          await secure.saveHotwaterIsn(current.id, null);
          _emitStart(RuntimeTaskState.failure, message);
        } else {
          final cleared = await clearHotwaterSessionLocally(
            expected: current,
            resultState: RuntimeTaskState.failure,
            message: message,
          );
          if (!cleared && _current(current, epoch)) {
            _emitStart(RuntimeTaskState.failure, message);
          }
        }
      } else {
        _emitStart(RuntimeTaskState.failure,
            error is HotwaterException ? error.message : '无法保存或查询热水会话，请重试');
      }
    } finally {
      final oldSession = previous.session;
      if (oldSession != null && state.hotwater.session?.id != oldSession.id) {
        try {
          await secure.saveHotwaterIsn(oldSession.id, null);
        } catch (_) {
          diagnosticLog.log('hotwater', '旧热水凭据清理失败');
        }
      }
    }
  }

  Future<void> stopHotwater() => stopActiveHotwater();
  Future<void> stopShower798() => stopActiveHotwater();

  /// 清除无法安全自动核对的本地热水会话；不会调用设备控制接口。
  Future<bool> clearUnreconciledHotwater() async {
    await ready;
    final session = state.hotwater.session;
    if (isDisposed || session == null) return false;
    var cleared = false;
    // 本地清理是控制意图边界，不能跨过它合并两次开始。
    _lastQueuedKey = null;
    _lastControlFuture = null;
    await _enqueue(() async {
      if (state.hotwater.session?.id != session.id) return;
      final isn = session.system == BathSystemPreference.zhuli
          ? await secure.loadHotwaterIsn(session.id)
          : null;
      if (state.hotwater.session?.phase == HotwaterSessionPhase.active &&
          isn != null &&
          isn.isNotEmpty) {
        return;
      }
      cleared = await clearHotwaterSessionLocally(
        expected: session,
        message: '已清除本地热水状态，设备状态仍需现场确认',
      );
    });
    return cleared;
  }

  Future<void> stopActiveHotwater() => _queueControl(null, false);

  Future<void> _stopSession(BathSystemPreference system, String device) async {
    final session = state.hotwater.session;
    if (_accountFor(system).isEmpty ||
        state.hotwaterLogin.isBusy ||
        state.shower798Login.isBusy) {
      _emitStop(RuntimeTaskState.loginRequired, '请先登录');
      return;
    }
    if (session != null && !_matchesAccount(session)) {
      _emitStop(RuntimeTaskState.loginRequired, '请登录开启热水时的账号');
      return;
    }
    final epoch = hotwaterAuthEpoch;
    final account = _accountFor(system);
    bool current() =>
        !isDisposed &&
        hotwaterAuthEpoch == epoch &&
        _accountFor(system) == account &&
        state.hotwater.session?.id == session?.id;
    _emitStop(RuntimeTaskState.loading, '正在关闭热水');
    try {
      if (system == BathSystemPreference.zhuli) {
        final isn =
            session == null ? null : await secure.loadHotwaterIsn(session.id);
        if (!current()) return;
        if (isn == null || isn.isEmpty) {
          _emitStop(RuntimeTaskState.loading, '正在更新订单');
          await loadHotwaterHistory();
          if (current()) {
            final status = state.hotwater.historyStatus;
            _emitStop(
                status.state,
                status.state == RuntimeTaskState.success
                    ? '订单已更新'
                    : status.message ?? '订单更新失败，请重试');
          }
          return;
        }
        await hotwater.stopHotwater(device, isn: isn);
      } else {
        if (device.isEmpty) {
          _emitStop(RuntimeTaskState.failure, '请先选择设备');
          return;
        }
        await shower798.stopShower(device);
      }
      if (!current()) return;
      if (session != null) {
        await _finishSession(session, '热水已关闭');
      } else {
        emit(state.copyWith(
            hotwater: state.hotwater.copyWith(
          running: false,
          start: const RuntimeActionStatus(message: '热水待启动'),
          stop: const RuntimeActionStatus(
              state: RuntimeTaskState.success, message: '热水已关闭'),
        )));
      }
      if (system == BathSystemPreference.zhuli &&
          !isDisposed &&
          epoch == hotwaterAuthEpoch) {
        await loadHotwaterHistory();
      }
    } catch (error) {
      if (current()) {
        _emitStop(
            RuntimeTaskState.failure,
            error is HotwaterException
                ? error.message
                : error is Shower798Exception
                    ? error.message
                    : '关水未确认，请重试');
      }
    }
  }

  @override
  // 保留只读手动刷新入口；不再由定时器调用或据订单判定结束。
  Future<void> pollHotwaterStatusOnce() async {
    final session = state.hotwater.session;
    if (isDisposed || pollingPaused || session == null || _sessionOperation) {
      return;
    }
    if (!_matchesAccount(session)) {
      return;
    }
    if (session.system == BathSystemPreference.zhuli) {
      await loadHotwaterHistory();
    }
  }

  Future<void> _finishSession(HotwaterSession session, String message) async {
    // 磁盘清除成功后才撤掉 UI，失败时下次查询仍可重试。
    final cleared = await clearHotwaterSessionLocally(
      expected: session,
      resultState: RuntimeTaskState.idle,
      message: '热水待启动',
      stopStatus: RuntimeActionStatus(
        state: RuntimeTaskState.success,
        message: message,
      ),
    );
    if (!cleared || isDisposed) return;
    if (session.system == BathSystemPreference.shower798) {
      emit(state.copyWith(
        shower798Devices: _mapDeviceStatus(session.deviceId, '空闲'),
        localDevices: _mapLocalStatus(session.deviceId, '空闲'),
      ));
      await devices.saveDevices(state.localDevices);
    }
  }

  /// 查询只更新订单，不改变本地开水状态；同一上下文合并请求。
  Future<void> loadHotwaterHistory() {
    if (isDisposed) return Future<void>.value();
    final epoch = hotwaterAuthEpoch;
    final account = state.zhuli.phone;
    final sessionId = state.hotwater.session?.id;
    final generation = _controlGeneration;
    final key = (epoch, account, sessionId, generation);
    if (_historyRequestKey == key && _historyRequest != null) {
      return _historyRequest!;
    }
    bool current() =>
        !isDisposed &&
        epoch == hotwaterAuthEpoch &&
        account == state.zhuli.phone &&
        sessionId == state.hotwater.session?.id &&
        generation == _controlGeneration;
    _historyRequestKey = key;
    late final Future<void> request;
    request = _refreshHistory(current).whenComplete(() {
      if (identical(_historyRequest, request)) {
        _historyRequest = null;
        _historyRequestKey = null;
      }
    });
    _historyRequest = request;
    return request;
  }

  Future<void> _refreshHistory(bool Function() current) async {
    emit(
      state.copyWith(
        hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在加载热水历史',
        ),
      ),
    );
    try {
      final orders = await hotwater.loadHistory();
      if (!current()) return;
      await history.saveHistory(orders);
      if (!current()) return;
      emit(
        state.copyWith(
          hotwaterHistory: orders,
          hotwaterHistoryStatus: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '热水历史已加载',
          ),
        ),
      );
    } catch (error) {
      if (!current()) return;
      if (error is HotwaterException && error.authInvalid) {
        await handleAuthInvalidation(AuthService.zhuli);
        if (isDisposed) return;
        emit(state.copyWith(
            hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.loginRequired,
          message: '请重新登录后更新订单',
        )));
        return;
      }
      emit(state.copyWith(
          hotwaterHistoryStatus: RuntimeActionStatus(
        state: RuntimeTaskState.failure,
        message: error is HotwaterException ? error.message : '订单更新失败，请重试',
      )));
    }
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

  /// 仅清除所属动作的旧错误，标题从保留的本地状态恢复。
  void _scheduleHotwaterErrorClearIfNeeded(RuntimeTaskState taskState) {
    final isError = taskState == RuntimeTaskState.failure ||
        taskState == RuntimeTaskState.loginRequired;
    if (!isError) {
      return;
    }
    scheduleHotwaterErrorClear(() {
      // 守卫：仅当到点时「仍处于错误态」才复位——若这 3 秒内用户已重试成功
      // （start=success）或正在处理（loading），保留那个新状态，不误清。
      final startErr = state.hotwaterStart.state == RuntimeTaskState.failure ||
          state.hotwaterStart.state == RuntimeTaskState.loginRequired;
      final stopErr = state.hotwaterStop.state == RuntimeTaskState.failure ||
          state.hotwaterStop.state == RuntimeTaskState.loginRequired;
      if (!startErr && !stopErr) {
        return;
      }
      emit(
        state.copyWith(
          hotwaterStart: startErr
              ? RuntimeActionStatus(
                  state: state.hotwaterRunning
                      ? RuntimeTaskState.success
                      : RuntimeTaskState.idle,
                  message: state.hotwaterRunning ? '热水使用中' : '热水待启动',
                )
              : null,
          hotwaterStop: stopErr ? const RuntimeActionStatus() : null,
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
