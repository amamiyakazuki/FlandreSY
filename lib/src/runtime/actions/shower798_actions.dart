// Shower798 login + device actions (Module P3; refactored in P4 S798 to orchestrate IShower798Adapter).
// The adapter supplies data (captcha image bytes / sms / login / devices) + IO latency; this mixin
// does validation + emit + cooldown-stamp + persist with an explicitly injected adapter. Field names + messages align 1:1 with legacy ShuiRuntime.kt Shower798 methods.

import 'dart:async';

import '../../data/account_session_repository.dart';
import '../../data/adapters/shower798_adapter.dart';
import '../models/account_session.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin Shower798Actions on ShuiRuntimeBase {
  /// 上一次图形验证码的 doubleRandom（sendSms 复用，对齐 legacy captcha→sms 关联）。
  String _lastCaptchaDoubleRandom = '';

  /// 请求图形验证码（经 IShower798Adapter；真实拉图片字节→base64，fake=fakeCaptchaBase64）。
  /// 对齐 legacy requestShower798Captcha。
  Future<void> requestShower798Captcha() async {
    await ready;
    if (legacyStorageBlocked) return;
    if (state.shower798Captcha.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        shower798Captcha: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在获取 798 图形验证码',
        ),
      ),
    );
    final Shower798CaptchaData captcha;
    try {
      captcha = await shower798.requestCaptcha();
    } on Shower798Exception catch (e) {
      emit(
        state.copyWith(
          shower798Captcha: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    _lastCaptchaDoubleRandom = captcha.doubleRandom;
    emit(
      state.copyWith(
        shower798Captcha: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '图形验证码已刷新',
        ),
        shower798CaptchaImageBase64: captcha.imageBase64,
      ),
    );
  }

  /// 发送短信验证码（fake：手机号 + 图形码非空 → 「短信验证码已发送」→ 触发 cooldown）。
  /// 对齐 legacy sendShower798SmsCode。
  Future<void> sendShower798SmsCode(String phone, String imageCaptcha) async {
    await ready;
    if (legacyStorageBlocked) return;
    if (state.shower798Captcha.isBusy) {
      return;
    }
    if (phone.trim().isEmpty) {
      emit(
        state.copyWith(
          shower798Captcha: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入 798 洗浴手机号',
          ),
        ),
      );
      return;
    }
    if (imageCaptcha.trim().isEmpty) {
      emit(
        state.copyWith(
          shower798Captcha: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入图形验证码',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        shower798Captcha: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在发送短信验证码',
        ),
      ),
    );
    try {
      await shower798.sendSmsCode(
        doubleRandom: _lastCaptchaDoubleRandom,
        imageCaptcha: imageCaptcha.trim(),
        phone: phone.trim(),
      );
    } on Shower798Exception catch (e) {
      emit(
        state.copyWith(
          shower798Captcha: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        shower798Captcha: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '短信验证码已发送',
        ),
        shower798CaptchaSentAtMillis: clock.nowMillis(),
      ),
    );
  }

  String _loginStage = '登录请求';

  /// 登录、读取列表与保存共同完成后才发布新身份。
  /// 对齐 legacy loginShower798。
  Future<void> loginShower798(String phone, String smsCode) async {
    await ready;
    if (legacyStorageBlocked) {
      emit(state.copyWith(
          shower798Login: const RuntimeActionStatus(
              state: RuntimeTaskState.failure, message: '旧数据保全未完成，请先重试保全')));
      return;
    }
    if (hotwaterAuthChanging || hotwaterAccountWriteCount > 0 || isDisposed) {
      return;
    }
    _loginStage = '登录请求';
    resetAccountAvailability(AccountKind.shower798);
    hotwaterAuthChanging = true;
    try {
      await _loginShower798(phone, smsCode);
    } catch (error) {
      diagnosticLog.log(
          'auth', '798登录失败 stage=$_loginStage type=${error.runtimeType}');
      hotwaterAuthChanging = false;
      final authInvalid = error is Shower798Exception && error.authInvalid;
      final detail = error is Shower798Exception
          ? error.message
          : (_loginStage.contains('保存') ? '本地保存失败' : '请求异常，请重试');
      await handleAuthInvalidation(
        AuthService.shower798,
        failureMessage: authInvalid ? null : '$_loginStage未完成：$detail；请重新登录',
      );
    } finally {
      hotwaterAuthChanging = false;
    }
  }

  Future<void> _loginShower798(String phone, String smsCode) async {
    await ready;
    if (isDisposed ||
        state.hotwaterStart.isBusy ||
        state.hotwaterStop.isBusy ||
        state.shower798Login.isBusy) {
      return;
    }
    final mobile = phone.trim();
    if (mobile.isEmpty || smsCode.trim().isEmpty) {
      emit(
        state.copyWith(
          shower798Login: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入手机号和短信验证码',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        shower798DevicesStatus: const RuntimeActionStatus(),
        shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在登录慧生活798',
        ),
      ),
    );
    final Shower798SessionData session;
    hotwaterAuthEpoch++;
    final List<Shower798DeviceUi> devices;
    try {
      session = await shower798.login(mobile, smsCode.trim());
      if (isDisposed) return;
      _loginStage = '登录后设备列表读取';
      devices = await shower798.loadDevices();
      if (isDisposed) return;
    } on Shower798Exception {
      // 包括登录后设备列表失败，由外层统一清理混合身份。
      rethrow;
    }
    final account = Shower798AccountUi(
      mobile: session.phone,
      uid: session.uid,
      eid: session.eid,
    );
    _loginStage = '登录信息保存';
    if (session.token.isNotEmpty) {
      await withShower798Storage(sessions.clearShower798);
      await secure.saveShower798Token(session.token);
      if (isDisposed) return;
    }
    await withShower798Storage(() => sessions.saveShower798(Shower798Persisted(
          account: account,
          devices: devices,
          currentDeviceId:
              devices.any((d) => d.id == state.currentShower798DeviceId)
                  ? state.currentShower798DeviceId
                  : '',
        )));
    _loginStage = '旧数据登录确认保存';
    await migration.confirmLogin('shower798');
    if (isDisposed) return;
    emit(
      state.copyWith(
        shower798Account: account,
        shower798Devices: devices,
        currentShower798DeviceId:
            devices.any((d) => d.id == state.currentShower798DeviceId)
                ? state.currentShower798DeviceId
                : '',
        shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '慧生活798登录成功，设备列表已刷新',
        ),
      ),
    );
    await setBathSystem(BathSystemPreference.shower798);
    unawaited(resumeHotwaterSession());
  }

  /// 查看 798 状态（对齐 legacy checkShower798Status）。
  Future<void> checkShower798Status() =>
      checkAccountStatus(AccountKind.shower798);

  Future<void> _deviceTail = Future<void>.value();
  Future<void>? _refresh;
  // A server-confirmed addition is not resent after a subsequent sync failure.
  final Set<String> _confirmedAdds = {};
  int _confirmedAddsEpoch = -1;

  bool _deviceContextCurrent(int epoch, String owner) =>
      !isDisposed &&
      !hotwaterAuthChanging &&
      epoch == hotwaterAuthEpoch &&
      legacyServiceReady('shower798') &&
      state.shower798Account?.mobile == owner;

  void _deviceStatus(RuntimeTaskState task, String message) {
    if (!isDisposed) {
      emit(state.copyWith(
          shower798DevicesStatus:
              RuntimeActionStatus(state: task, message: message)));
    }
  }

  Future<void> _queueDevices(
      String label, Future<void> Function(int, String) action) async {
    await ready;
    if (isDisposed) return;
    final owner = state.shower798Account?.mobile ?? '';
    if (hotwaterAuthChanging ||
        !legacyServiceReady('shower798') ||
        owner.isEmpty) {
      _deviceStatus(RuntimeTaskState.failure, '请先完成 798 登录和旧数据保全');
      return;
    }
    final epoch = hotwaterAuthEpoch;
    hotwaterAccountWriteCount++;
    final result = _deviceTail.then((_) async {
      if (!_deviceContextCurrent(epoch, owner)) return;
      if (_confirmedAddsEpoch != epoch) {
        _confirmedAdds.clear();
        _confirmedAddsEpoch = epoch;
      }
      _deviceStatus(RuntimeTaskState.loading, label);
      try {
        await action(epoch, owner);
      } on Shower798Exception catch (e) {
        if (!_deviceContextCurrent(epoch, owner)) return;
        if (e.authInvalid) {
          await handleAuthInvalidation(AuthService.shower798,
              expectedEpoch: epoch);
        } else {
          _deviceStatus(RuntimeTaskState.failure, e.message);
        }
      } catch (error) {
        if (_deviceContextCurrent(epoch, owner)) {
          diagnosticLog.log('storage', '798设备操作失败 type=${error.runtimeType}');
          _deviceStatus(RuntimeTaskState.failure, '设备列表或选择未保存，请重试；原记录已保留');
        }
      }
    });
    _deviceTail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    try {
      await result;
    } finally {
      hotwaterAccountWriteCount--;
    }
  }

  /// Publish a whole snapshot only after storage confirms it. Cleanup shares the
  /// storage queue and invalidates the epoch before waiting for an active save.
  Future<bool> _commitDevices(int epoch, String owner,
      List<Shower798DeviceUi> devices, String selected) async {
    return withShower798Storage(() async {
      if (!_deviceContextCurrent(epoch, owner)) return false;
      final account = state.shower798Account!;
      await sessions.saveShower798(Shower798Persisted(
        account: account,
        devices: devices,
        currentDeviceId: selected,
      ));
      if (!_deviceContextCurrent(epoch, owner)) return false;
      emit(state.copyWith(
          shower798Devices: devices, currentShower798DeviceId: selected));
      return true;
    });
  }

  Future<void> addShower798Device(String deviceId) =>
      _queueDevices('正在添加并同步设备', (epoch, owner) async {
        final id = deviceId.trim();
        if (id.isEmpty) {
          _deviceStatus(RuntimeTaskState.failure, '请输入设备号');
          return;
        }
        if (state.shower798Devices.any((d) => d.id == id)) {
          if (await _commitDevices(epoch, owner, state.shower798Devices, id)) {
            _deviceStatus(RuntimeTaskState.success, '当前设备已保存：$id');
          }
          return;
        }
        if (!_confirmedAdds.contains(id)) {
          await shower798.addDevice(id);
          if (!_deviceContextCurrent(epoch, owner)) return;
          _confirmedAdds.add(id);
        }
        var stage = '同步';
        try {
          final devices = await shower798.loadDevices();
          if (!_deviceContextCurrent(epoch, owner)) return;
          if (!devices.any((d) => d.id == id)) {
            _deviceStatus(
                RuntimeTaskState.failure, '添加请求已确认，但列表尚未包含该设备，请刷新列表核对');
            return;
          }
          stage = '保存';
          if (await _commitDevices(epoch, owner, devices, id)) {
            _confirmedAdds.remove(id);
            _deviceStatus(RuntimeTaskState.success, '设备已添加并保存：$id');
          }
        } catch (error) {
          if (!_deviceContextCurrent(epoch, owner)) return;
          if (error is Shower798Exception && error.authInvalid) {
            await handleAuthInvalidation(AuthService.shower798,
                expectedEpoch: epoch,
                failureMessage: '添加请求已确认，但登录已失效，请重新登录后刷新列表核对');
            return;
          }
          _deviceStatus(
              RuntimeTaskState.failure, '添加请求已确认，列表尚未$stage，请刷新列表重试；不会自动重发添加');
        }
      });

  Future<void> refreshShower798Devices() {
    final pending = _refresh;
    if (pending != null) return pending;
    late final Future<void> operation;
    operation = _queueDevices('正在刷新设备列表', (epoch, owner) async {
      final devices = await shower798.loadDevices();
      if (!_deviceContextCurrent(epoch, owner)) return;
      final oldSelected = state.currentShower798DeviceId;
      final selected =
          devices.any((d) => d.id == oldSelected) ? oldSelected : '';
      if (await _commitDevices(epoch, owner, devices, selected)) {
        _confirmedAdds.removeWhere((id) => devices.any((d) => d.id == id));
        _deviceStatus(
            RuntimeTaskState.success,
            oldSelected.isNotEmpty && selected.isEmpty
                ? '设备列表已保存；原设备已不在列表中，请重新选择'
                : '设备列表已刷新并保存');
      }
    }).whenComplete(() {
      if (identical(_refresh, operation)) _refresh = null;
    });
    _refresh = operation;
    return operation;
  }

  Future<void> selectShower798Device(String deviceId) =>
      _queueDevices('正在保存当前设备', (epoch, owner) async {
        if (!state.shower798Devices.any((d) => d.id == deviceId)) {
          _deviceStatus(RuntimeTaskState.failure, '设备已不在列表中，请刷新后重新选择');
          return;
        }
        if (await _commitDevices(
            epoch, owner, state.shower798Devices, deviceId)) {
          _deviceStatus(RuntimeTaskState.success, '当前设备已保存');
        }
      });

  @override
  Future<void> recordShower798StopConfirmation(
      String deviceId, String owner) async {
    // Only records the already-confirmed request; never sends a control action.
    if (state.shower798Account?.mobile != owner) return;
    await _queueDevices('正在保存请求确认', (epoch, currentOwner) async {
      if (currentOwner != owner) return;
      final devices = state.shower798Devices
          .map((d) => d.id == deviceId
              ? Shower798DeviceUi(
                  id: d.id,
                  name: d.name,
                  lastStatus: '停止请求已确认',
                  statusConfirmed: true)
              : d)
          .toList();
      if (await _commitDevices(
          epoch, owner, devices, state.currentShower798DeviceId)) {
        _deviceStatus(RuntimeTaskState.success, '停止请求确认已保存，请核对设备');
      }
    });
  }
}
