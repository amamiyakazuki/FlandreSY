// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Shower798 login + device actions (Module P3; refactored in P4 S798 to orchestrate IShower798Adapter).
// The adapter supplies data (captcha image bytes / sms / login / devices) + IO latency; this mixin
// does validation + emit + cooldown-stamp + persist. Default FakeShower798Adapter (fakeCaptchaBase64),
// real on device. Field names + messages align 1:1 with legacy ShuiRuntime.kt Shower798 methods.

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

  /// 登录慧生活798（fake：手机号 + 短信码非空 → 成功 + 加载 fake 设备列表）。
  /// 对齐 legacy loginShower798。
  Future<void> loginShower798(String phone, String smsCode) async {
    if (state.shower798Login.isBusy) {
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
        shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在登录慧生活798',
        ),
      ),
    );
    final Shower798SessionData session;
    final List<Shower798DeviceUi> devices;
    try {
      session = await shower798.login(mobile, smsCode.trim());
      devices = await shower798.loadDevices();
    } on Shower798Exception catch (e) {
      emit(
        state.copyWith(
          shower798Login: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    final account = Shower798AccountUi(
      mobile: session.phone,
      uid: session.uid,
      eid: session.eid,
    );
    emit(
      state.copyWith(
        shower798Account: account,
        shower798Devices: devices,
        shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '慧生活798登录成功，设备列表已刷新',
        ),
      ),
    );
    await _persist();
    // PTOK：real 模式下 adapter 返回带真 token 的 session → 加密持久化（重启免重登）。
    // Fake 返回占位 token（'fake-798-token'）也会存——无害（重启仍走 Fake adapter）。
    if (session.token.isNotEmpty) {
      await secure.saveShower798Token(session.token);
    }
  }

  /// 查看 798 状态（对齐 legacy checkShower798Status）。
  void checkShower798Status() {
    final account = state.shower798Account;
    emit(
      state.copyWith(
        shower798Login: account == null
            ? const RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired,
                message: '慧生活798未登录',
              )
            : RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message: '慧生活798账号：${account.mobile}',
              ),
      ),
    );
  }

  /// 添加 798 设备（经 IShower798Adapter：add → reload；已存在则仅设为当前）。
  /// 对齐 legacy addShower798Device。
  Future<void> addShower798Device(String deviceId) async {
    final id = deviceId.trim();
    if (id.isEmpty) {
      emit(
        state.copyWith(
          shower798Login: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入设备号',
          ),
        ),
      );
      return;
    }
    if (state.shower798Devices.any((d) => d.id == id)) {
      emit(
        state.copyWith(currentShower798DeviceId: id),
      );
      await _persist();
      return;
    }
    final List<Shower798DeviceUi> devices;
    try {
      await shower798.addDevice(id);
      devices = await shower798.loadDevices();
    } on Shower798Exception catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.shower798);
        return;
      }
      emit(
        state.copyWith(
          shower798Login: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        shower798Devices: devices,
        currentShower798DeviceId: id,
        shower798Login: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '已添加设备：$id',
        ),
      ),
    );
    await _persist();
  }

  /// 刷新 798 设备列表（经 IShower798Adapter.loadDevices）。对齐 legacy refreshShower798Devices。
  Future<void> refreshShower798Devices() async {
    if (state.shower798Login.isBusy) {
      return;
    }
    final List<Shower798DeviceUi> refreshed;
    try {
      refreshed = await shower798.loadDevices();
    } on Shower798Exception catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.shower798);
        return;
      }
      emit(
        state.copyWith(
          shower798Login: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        shower798Devices: refreshed,
        shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '设备列表已刷新',
        ),
      ),
    );
    await _persist();
  }

  /// 选择当前 798 设备（对齐 legacy selectShower798Device）。
  Future<void> selectShower798Device(String deviceId) async {
    if (state.currentShower798DeviceId == deviceId) {
      return;
    }
    emit(state.copyWith(currentShower798DeviceId: deviceId));
    await _persist();
  }

  Future<void> _persist() async {
    final account = state.shower798Account;
    if (account == null) {
      return;
    }
    await sessions.saveShower798(
      Shower798Persisted(
        account: account,
        devices: state.shower798Devices,
        currentDeviceId: state.currentShower798DeviceId,
      ),
    );
  }
}
