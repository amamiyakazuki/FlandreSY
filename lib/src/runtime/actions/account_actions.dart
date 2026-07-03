// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Account login actions (Module P2; U净 refactored in P4 A1 to orchestrate IUjingAdapter;
// 住理 wired to IHotwaterAdapter in Z2-fix so real login populates the adapter session).
// Boundary: Zhuli (住理) + Ujing (U净) login both go through their adapter (Fake by default,
// real HTTP on device). 798 lives in shower798_actions. All paths persist via AccountSessionRepository.
// Field names + messages align 1:1 with legacy ShuiRuntime.kt login methods.

import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../../data/adapters/ujing_adapter.dart';
import '../../data/adapters/ujing_http_adapter.dart';
import '../models/account_session.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin AccountActions on ShuiRuntimeBase {
  /// 住理生活登录（经 `hotwater` adapter）。对齐 legacy loginHotwater。
  ///
  /// Fake：620ms 延迟 + 占位 session（时序/文案与原内联 fake 1:1，零行为变化）。
  /// 真实（RealZhuliAdapter）：平台签名 HTTP 登录并在 adapter 内部持 session
  /// （startHotwater/stopHotwater 依赖 `_requireSession()`，否则「一点开水就显示未登录」）。
  Future<void> loginZhuli(String phone, String password) async {
    if (state.hotwaterLogin.isBusy) {
      return;
    }
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty || password.trim().isEmpty) {
      emit(
        state.copyWith(
          hotwaterLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入手机号和密码',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        hotwaterLogin: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在登录住理生活',
        ),
      ),
    );
    final ZhuliSessionData sessionData;
    try {
      sessionData = await hotwater.loginZhuli(normalizedPhone, password.trim());
    } on HotwaterException catch (e) {
      emit(
        state.copyWith(
          hotwaterLogin: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    final session = state.zhuli.copyWith(phone: normalizedPhone);
    emit(
      state.copyWith(
        zhuli: session,
        hotwaterLogin: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '住理生活已登录：$normalizedPhone',
        ),
      ),
    );
    await sessions.saveZhuli(session);
    // PTOK：real 模式下 adapter 返回带 secretKey 的真 session → 加密持久化（重启免重登）。
    // Fake 返回占位 session（secretKey='fake-secret'）也会存——无害（重启仍走 Fake adapter）。
    if (sessionData.isValid) {
      await secure.saveZhuliSession(sessionData);
    }
  }

  /// 绑定热水设备码（对齐 legacy bindHotwaterDeviceCode）。
  Future<void> bindHotwaterDeviceCode(String deviceId) async {
    final normalized = deviceId.trim();
    if (normalized.isEmpty) {
      emit(
        state.copyWith(
          hotwaterLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入热水设备码',
          ),
        ),
      );
      return;
    }
    final session = state.zhuli.copyWith(deviceCode: normalized);
    emit(
      state.copyWith(
        zhuli: session,
        hotwaterLogin: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '已绑定热水设备码：$normalized',
        ),
      ),
    );
    await sessions.saveZhuli(session);
  }

  /// 查看住理状态（对齐 legacy checkHotwaterStatus）。
  void checkZhuliStatus() {
    final s = state.zhuli;
    emit(
      state.copyWith(
        hotwaterLogin: s.isLoggedIn
            ? RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message:
                    '住理生活账号：${s.phone}；热水设备码：${s.deviceCode.isEmpty ? '未绑定' : s.deviceCode}',
              )
            : const RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired,
                message: '住理生活未登录',
              ),
      ),
    );
  }

  /// 请求 U净验证码（fake：手机号非空即「已发送」，触发 30s cooldown）。
  /// 对齐 legacy requestUjingCaptcha。
  Future<void> requestUjingCaptcha(String phone) async {
    if (state.ujingCaptcha.isBusy) {
      return;
    }
    if (phone.trim().isEmpty) {
      emit(
        state.copyWith(
          ujingCaptcha: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入手机号',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        ujingCaptcha: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在获取 U净验证码',
        ),
      ),
    );
    try {
      await ujing.requestCaptcha(phone.trim());
    } on UjingException catch (e) {
      emit(
        state.copyWith(
          ujingCaptcha: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        ujingCaptcha: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '验证码已发送',
        ),
        ujingCaptchaSentAtMillis: clock.nowMillis(),
      ),
    );
  }

  /// U净登录（经 IUjingAdapter；fake 派生账号，真实由接口返回）。
  /// 对齐 legacy loginUjing。
  Future<void> loginUjing(String phone, String captcha) async {
    if (state.washerLogin.isBusy) {
      return;
    }
    final mobile = phone.trim();
    if (mobile.isEmpty || captcha.trim().isEmpty) {
      emit(
        state.copyWith(
          washerLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: '请输入手机号和验证码',
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        washerLogin: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在登录 U净',
        ),
      ),
    );
    final UjingAccountUi account;
    try {
      account = await ujing.login(mobile, captcha.trim());
    } on UjingException catch (e) {
      emit(
        state.copyWith(
          washerLogin: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        ujingAccount: account,
        washerLogin: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: 'U净登录成功',
        ),
      ),
    );
    await sessions.saveUjing(account);
    // PTOK：real 模式下从 UjingHttpAdapter 读登录 token → 加密持久化（重启免重登）。
    // Fake 无此 getter（不是 UjingHttpAdapter）→ 跳过，不落密钥。
    final adapter = ujing;
    if (adapter is UjingHttpAdapter) {
      final token = adapter.lastToken;
      if (token != null && token.isNotEmpty) {
        await secure.saveUjingToken(token);
      }
    }
  }

  /// 查看 U净状态（对齐 legacy checkUjingStatus）。
  void checkUjingStatus() {
    final account = state.ujingAccount;
    emit(
      state.copyWith(
        washerLogin: account == null
            ? const RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired,
                message: 'U净未登录',
              )
            : RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message: 'U净账号：${account.mobile}',
              ),
      ),
    );
  }
}
