// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius/sms sizing.
// Reference: P_PLAN/...Reference.md §4.8 + legacy ShuiScreens.kt UjingAccountDetail (2712).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_text_field.dart';

/// U净登录详情（手机号 + 验证码[30s cooldown] → 登录）。
/// cooldown 用本地 Timer，dispose 取消（防 test teardown pending timer）。
class UjingAccountDetail extends StatefulWidget {
  const UjingAccountDetail({
    required this.state,
    required this.nowMillis,
    required this.onRequestCaptcha,
    required this.onLogin,
    required this.onCheckStatus,
    super.key,
  });

  final ShuiHomeState state;

  /// 当前 clock 毫秒。cooldown 从 state.ujingCaptchaSentAtMillis 按真实经过时间恢复，
  /// 不再依赖 widget 局部标志 → 离开/返回详情页不会把 cooldown 重置回 30s。
  final int nowMillis;
  final ValueChanged<String> onRequestCaptcha;
  final void Function(String phone, String captcha) onLogin;
  final VoidCallback onCheckStatus;

  @override
  State<UjingAccountDetail> createState() => _UjingAccountDetailState();
}

class _UjingAccountDetailState extends State<UjingAccountDetail> {
  late final TextEditingController _mobile =
      TextEditingController(text: widget.state.ujingAccount?.mobile ?? '');
  final TextEditingController _captcha = TextEditingController();

  int _cooldown = 0;
  Timer? _cooldownTimer;

  /// 已按哪个「发送时刻」seed 过 cooldown。避免每帧重复 seed 把本地倒计时顶回 30s。
  int _syncedSentAt = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _mobile.dispose();
    _captcha.dispose();
    super.dispose();
  }

  /// 从 state 的「验证码已发送时刻」按真实经过时间 seed cooldown，再交本地 Timer 每秒递减。
  /// 关键：每个 sentAt 只 seed 一次（_syncedSentAt 守卫），否则本地递减会被每帧重新 seed 顶回。
  /// 这样既修「离开→返回详情页重置 30s」（新 widget 实例按经过时间恢复剩余），
  /// 又保持本地 Timer 递减（golden 用虚拟 pump 时间确定性递减、可 settle）。
  void _syncCooldown() {
    final sentAt = widget.state.ujingCaptchaSentAtMillis;
    if (sentAt <= 0 || sentAt == _syncedSentAt) {
      return;
    }
    _syncedSentAt = sentAt;
    final elapsed = (widget.nowMillis - sentAt) ~/ 1000;
    final remain = AppCustomTokens.smsCooldownSeconds - elapsed;
    _cooldown = remain < 0 ? 0 : remain;
    _cooldownTimer?.cancel();
    if (_cooldown > 0) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _cooldown -= 1;
          if (_cooldown <= 0) {
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncCooldown();
    final s = widget.state;
    final captchaLoading = s.ujingCaptcha.isBusy;
    final loginLoading = s.washerLogin.isBusy;
    final busy = captchaLoading || loginLoading;
    final loggedIn = s.ujingAccount != null &&
        s.washerLogin.state != RuntimeTaskState.loginRequired;
    final account = s.ujingAccount;
    return Column(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: ShuiAssets.shuiU, title: 'U净账号'),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              RuntimeStatusBanner(status: s.washerLogin),
              if (s.ujingCaptcha.message != null) ...[
                const SizedBox(height: AppCustomTokens.spaceXs),
                RuntimeStatusBanner(status: s.ujingCaptcha),
              ],
              const SizedBox(height: AppCustomTokens.formFieldGap),
              ShuiTextField(
                controller: _mobile,
                label: '手机号',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ShuiTextField(
                      controller: _captcha,
                      label: '验证码',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppCustomTokens.spaceSm),
                  SizedBox(
                    width: AppCustomTokens.smsButtonWidth,
                    height: AppCustomTokens.smsButtonHeight,
                    child: PrimaryGradientButton(
                      label: captchaLoading
                          ? '发送中'
                          : (_cooldown > 0 ? '${_cooldown}s' : '发送验证码'),
                      enabled: !busy && _cooldown == 0,
                      onTap: () => widget.onRequestCaptcha(_mobile.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              Row(
                children: [
                  Expanded(
                    child: PrimaryGradientButton(
                      label: loginLoading
                          ? '登录中'
                          : (loggedIn ? '已登录' : '点击登录'),
                      enabled: !busy,
                      compact: true,
                      onTap: () => widget.onLogin(_mobile.text, _captcha.text),
                    ),
                  ),
                  const SizedBox(width: AppCustomTokens.formFieldGap),
                  Expanded(
                    child: PrimaryGradientButton(
                      label: '查看状态',
                      enabled: !busy,
                      compact: true,
                      onTap: widget.onCheckStatus,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppCustomTokens.spaceSm),
              Text(
                account != null
                    ? '账号：${account.mobile} / 用户 ${account.userId}'
                    : '暂无已登录账号',
                // P2 截断修复：手机号 + userId 拼接超宽，允许两行不裁账号身份。
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
