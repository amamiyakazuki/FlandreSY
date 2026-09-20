// Account login actions (Module P2; U净 refactored in P4 A1 to orchestrate IUjingAdapter;
// 住理 wired to IHotwaterAdapter in Z2-fix so real login populates the adapter session).
// Boundary: Zhuli (住理) + Ujing (U净) login both go through their adapter (Fake by default,
// real HTTP on device). 798 lives in shower798_actions. All paths persist via AccountSessionRepository.
// Field names + messages align 1:1 with legacy ShuiRuntime.kt login methods.

import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../../data/adapters/ujing_adapter.dart';
import '../../data/adapters/ujing_http_adapter.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin AccountActions on ShuiRuntimeBase {
  /// 住理生活登录（经 `hotwater` adapter）。对齐 legacy loginHotwater。
  ///
  /// Fake：620ms 延迟 + 占位 session（时序/文案与原内联 fake 1:1，零行为变化）。
  /// 真实（RealZhuliAdapter）：平台签名 HTTP 登录并在 adapter 内部持 session
  /// （startHotwater/stopHotwater 依赖 `_requireSession()`，否则「一点开水就显示未登录」）。
  Future<void> loginZhuli(String phone, String password) async {
    await ready;
    if (hotwaterAuthChanging || hotwaterAccountWriteCount > 0 || isDisposed) {
      return;
    }
    hotwaterAuthChanging = true;
    try {
      await _loginZhuli(phone, password);
    } catch (error) {
      diagnosticLog.log('auth', '住理登录保存失败 type=${error.runtimeType}');
      hotwaterAuthChanging = false;
      await handleAuthInvalidation(AuthService.zhuli);
    } finally {
      hotwaterAuthChanging = false;
    }
  }

  Future<void> _loginZhuli(String phone, String password) async {
    await ready;
    if (isDisposed ||
        state.hotwaterStart.isBusy ||
        state.hotwaterStop.isBusy ||
        state.hotwaterLogin.isBusy) {
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
    hotwaterAuthEpoch++;
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
    if (sessionData.isValid) {
      await sessions.clearZhuli();
      await secure.saveZhuliSession(sessionData);
    }
    await sessions.saveZhuli(session);
    emit(
      state.copyWith(
        zhuli: session,
        hotwaterLogin: RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '住理生活已登录：$normalizedPhone',
        ),
      ),
    );
    await setBathSystem(BathSystemPreference.zhuli);
    unawaited(resumeHotwaterSession());
  }

  /// 绑定热水设备码（对齐 legacy bindHotwaterDeviceCode）。
  Future<void> bindHotwaterDeviceCode(String deviceId) async {
    await ready;
    if (isDisposed || hotwaterAuthChanging) return;
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
    hotwaterAccountWriteCount++;
    try {
      await sessions.saveZhuli(session);
    } catch (error) {
      diagnosticLog.log('storage', '设备码保存失败 type=${error.runtimeType}');
      emit(state.copyWith(
          hotwaterLogin: const RuntimeActionStatus(
        state: RuntimeTaskState.failure,
        message: '设备码尚未保存，请重试',
      )));
    } finally {
      hotwaterAccountWriteCount--;
    }
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
    await ready;
    if (isDisposed || ujingAuthChanging || state.washerLogin.isBusy) {
      return;
    }
    if (ujingMutationCount > 0) {
      emit(state.copyWith(
          washerLogin: const RuntimeActionStatus(
        state: RuntimeTaskState.unavailable,
        message: '订单操作正在处理，请完成后再切换账号',
      )));
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
    ujingAuthChanging = true;
    beginUjingLoginEpoch();
    stopWaterPolling();
    emit(
      state.copyWith(
        clearWaterReady: true,
        clearWaterResult: true,
        devicesRefresh: const RuntimeActionStatus(),
        waterScan: const RuntimeActionStatus(),
        waterOrder: const RuntimeActionStatus(),
        washer: state.washer.copyWith(
          clearProgram: true,
          clearPayment: true,
          washerScan: const RuntimeActionStatus(),
          washerOrder: const RuntimeActionStatus(),
          washerPayment: const RuntimeActionStatus(),
        ),
        washerLogin: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在登录 U净',
        ),
      ),
    );
    try {
      final account = await ujing.login(mobile, captcha.trim());
      if (isDisposed) return;
      final adapter = ujing;
      if (adapter is UjingHttpAdapter) {
        final token = adapter.lastToken;
        if (token == null || token.isEmpty) {
          throw const UjingException('登录未返回有效凭据');
        }
        await sessions.clearUjing();
        await secure.saveUjingToken(token);
      }
      await sessions.saveUjing(account);
      emit(
        state.copyWith(
          ujingAccount: account,
          washerLogin: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: 'U净登录成功',
          ),
        ),
      );
    } catch (error) {
      // 登录或落盘失败不能留下新 token + 旧账号的混合身份。
      final adapter = ujing;
      if (adapter is UjingHttpAdapter) adapter.invalidateAuth();
      emit(state.copyWith(
        clearUjingAccount: true,
        washerLogin: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message:
                error is UjingException ? error.message : '登录状态保存失败，请重新登录'),
      ));
      try {
        await Future.wait([secure.clearUjingToken(), sessions.clearUjing()]);
      } catch (cleanupError) {
        diagnosticLog.log('auth', '登录失败后清理失败 type=${cleanupError.runtimeType}');
      }
    } finally {
      ujingAuthChanging = false;
    }
    if (!isDisposed && state.ujingAccount != null) {
      await resumeUjingOrders();
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
