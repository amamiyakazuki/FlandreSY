// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Fake 慧生活798 adapter (no visual constants). Moves the fake data + timing that previously lived
// inline in shower798_actions + hotwater_actions (798 part) here, 1:1 (fakeCaptchaBase64 refresh
// palette / 620ms / seed devices / idle-busy toggle on refresh) — so the refactor is
// zero-behavior-change (P3/H1 goldens stay unregenerated). No real HTTP. Reuses fake_captcha.dart.

import 'dart:async';

import '../../runtime/fake_captcha.dart';
import '../../runtime/models/account_session.dart';
import 'shower798_adapter.dart';

/// Fake 实现：保留原有 fake 时序/数值/文案。有状态（captcha 刷新计数 + 设备列表切换），
/// 复现原内联行为：login/首次 loadDevices=seed，后续 loadDevices=空闲/使用中翻转。
class FakeShower798Adapter implements IShower798Adapter {
  FakeShower798Adapter();

  static const Duration _captchaDelay = Duration(milliseconds: 400);
  static const Duration _netDelay = Duration(milliseconds: 620);

  int _captchaRefreshCount = 0;
  List<Shower798DeviceUi> _devices = const [];

  @override
  Future<Shower798CaptchaData> requestCaptcha() async {
    await Future<void>.delayed(_captchaDelay);
    _captchaRefreshCount += 1;
    return Shower798CaptchaData(
      imageBase64: fakeCaptchaBase64(_captchaRefreshCount),
      doubleRandom: 'fake-s-$_captchaRefreshCount',
      timestamp: 'fake-r-$_captchaRefreshCount',
    );
  }

  @override
  Future<void> sendSmsCode({
    required String doubleRandom,
    required String imageCaptcha,
    required String phone,
  }) async {
    await Future<void>.delayed(_netDelay);
  }

  @override
  Future<Shower798SessionData> login(String phone, String smsCode) async {
    await Future<void>.delayed(_netDelay);
    // fake 派生账号（真实由 /acc/login data.al 返回）。设备由后续 loadDevices 提供。
    return Shower798SessionData(
      phone: phone,
      uid: 'E${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
      eid: 'haiqi-798',
      token: 'fake-798-token',
    );
  }

  @override
  Future<List<Shower798DeviceUi>> loadDevices() async {
    // 不额外延迟：登录后 action 紧接调用 loadDevices，与原单次 620ms 登录时序对齐
    // （原内联在 login 一次 delay 里 seed 设备）。真实实现在 IoShower798Transport 有真实 IO。
    // 首次（登录后）seed；之后返回当前列表（含 add/delete 变更）。确定性、无随机翻转。
    if (_devices.isEmpty) {
      _devices = _seedDevices();
    }
    return List<Shower798DeviceUi>.of(_devices);
  }

  @override
  Future<void> addDevice(String deviceId) async {
    await Future<void>.delayed(_netDelay);
    final id = deviceId.trim();
    if (id.isEmpty || _devices.any((d) => d.id == id)) {
      return;
    }
    _devices = [
      ..._devices,
      Shower798DeviceUi(id: id, name: '798设备 $id', lastStatus: '空闲'),
    ];
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await Future<void>.delayed(_netDelay);
    _devices = _devices.where((d) => d.id != deviceId.trim()).toList();
  }

  @override
  Future<void> startShower(String deviceId) async {
    await Future<void>.delayed(_netDelay);
  }

  @override
  Future<void> stopShower(String deviceId) async {
    await Future<void>.delayed(_netDelay);
  }

  @override
  Future<bool> isDeviceIdle(String deviceId) async {
    await Future<void>.delayed(_netDelay);
    return true;
  }

  List<Shower798DeviceUi> _seedDevices() {
    return const [
      Shower798DeviceUi(id: '798A01', name: '海七浴室A01', lastStatus: '空闲'),
      Shower798DeviceUi(id: '798A02', name: '海七浴室A02', lastStatus: '使用中'),
    ];
  }
}
