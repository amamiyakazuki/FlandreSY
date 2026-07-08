// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Account sub-state (no visual constants). Extracted from ShuiHomeState to keep the aggregate
// from bloating as account services grow (Grok P2 Major: runtime aggregation). P3 (798) fields
// will land here, not on the top-level state.

import 'package:flutter/foundation.dart';

import 'models/account_session.dart';
import 'runtime_status.dart';

/// 账号登录子状态（Zhuli + U净；P3 的 798 字段也归入此处）。
/// 不可变 + copyWith。由 [ShuiHomeState.account] 持有。
@immutable
class AccountState {
  const AccountState({
    this.zhuli = const ZhuliSession(phone: ''),
    this.hotwaterLogin = const RuntimeActionStatus(
      state: RuntimeTaskState.loginRequired,
      message: '住理生活未登录',
    ),
    this.ujingAccount,
    this.washerLogin = const RuntimeActionStatus(
      state: RuntimeTaskState.loginRequired,
      message: 'U净未登录',
    ),
    this.ujingCaptcha = const RuntimeActionStatus(),
    this.ujingCaptchaSentAtMillis = 0,
    // ===== P3 慧生活798 字段 =====
    this.shower798Account,
    this.shower798Login = const RuntimeActionStatus(
      state: RuntimeTaskState.loginRequired,
      message: '慧生活798未登录',
    ),
    this.shower798Captcha = const RuntimeActionStatus(),
    this.shower798CaptchaSentAtMillis = 0,
    this.shower798CaptchaImageBase64,
    this.shower798Devices = const <Shower798DeviceUi>[],
    this.currentShower798DeviceId = '',
  });

  /// 住理生活 session（phone + deviceCode）。phone 空 = 未登录。
  final ZhuliSession zhuli;

  /// 住理登录动作状态（loginRequired/loading/success/failure）。
  final RuntimeActionStatus hotwaterLogin;

  /// U净账号（null = 未登录）。
  final UjingAccountUi? ujingAccount;

  /// U净登录动作状态。
  final RuntimeActionStatus washerLogin;

  /// U净验证码请求状态（含 cooldown 触发判定）。
  final RuntimeActionStatus ujingCaptcha;

  /// U净验证码「已发送」的时刻（clock 毫秒）。0 = 未发送。
  /// 存在 state 里而非 widget 局部，让 cooldown 在离开/返回详情页后仍能按真实经过时间恢复
  /// （修复「每次切回都重置为 30s」）。
  final int ujingCaptchaSentAtMillis;

  // ===== P3 慧生活798 字段 =====
  /// 798 账号（null = 未登录）。
  final Shower798AccountUi? shower798Account;

  /// 798 登录动作状态。
  final RuntimeActionStatus shower798Login;

  /// 798 图形验证码请求状态（含短信 cooldown 触发判定）。
  final RuntimeActionStatus shower798Captcha;

  /// 798 短信验证码「已发送」的时刻（clock 毫秒）。0 = 未发送。同 [ujingCaptchaSentAtMillis]。
  final int shower798CaptchaSentAtMillis;

  /// 798 图形验证码图片 base64（null = 未获取，显示占位）。
  final String? shower798CaptchaImageBase64;

  /// 798 已绑定设备列表。
  final List<Shower798DeviceUi> shower798Devices;

  /// 当前选中的 798 设备 id（空 = 未选）。
  final String currentShower798DeviceId;

  bool get shower798LoggedIn => shower798Account != null;

  AccountState copyWith({
    ZhuliSession? zhuli,
    RuntimeActionStatus? hotwaterLogin,
    RuntimeActionStatus? washerLogin,
    RuntimeActionStatus? ujingCaptcha,
    int? ujingCaptchaSentAtMillis,
    UjingAccountUi? ujingAccount,
    bool clearUjingAccount = false,
    // P3 798 字段。
    RuntimeActionStatus? shower798Login,
    RuntimeActionStatus? shower798Captcha,
    int? shower798CaptchaSentAtMillis,
    List<Shower798DeviceUi>? shower798Devices,
    String? currentShower798DeviceId,
    Shower798AccountUi? shower798Account,
    bool clearShower798Account = false,
    String? shower798CaptchaImageBase64,
    bool clearShower798Captcha = false,
  }) {
    return AccountState(
      zhuli: zhuli ?? this.zhuli,
      hotwaterLogin: hotwaterLogin ?? this.hotwaterLogin,
      ujingAccount:
          clearUjingAccount ? null : (ujingAccount ?? this.ujingAccount),
      washerLogin: washerLogin ?? this.washerLogin,
      ujingCaptcha: ujingCaptcha ?? this.ujingCaptcha,
      ujingCaptchaSentAtMillis:
          ujingCaptchaSentAtMillis ?? this.ujingCaptchaSentAtMillis,
      shower798Account: clearShower798Account
          ? null
          : (shower798Account ?? this.shower798Account),
      shower798Login: shower798Login ?? this.shower798Login,
      shower798Captcha: shower798Captcha ?? this.shower798Captcha,
      shower798CaptchaSentAtMillis:
          shower798CaptchaSentAtMillis ?? this.shower798CaptchaSentAtMillis,
      shower798CaptchaImageBase64: clearShower798Captcha
          ? null
          : (shower798CaptchaImageBase64 ?? this.shower798CaptchaImageBase64),
      shower798Devices: shower798Devices ?? this.shower798Devices,
      currentShower798DeviceId:
          currentShower798DeviceId ?? this.currentShower798DeviceId,
    );
  }
}
