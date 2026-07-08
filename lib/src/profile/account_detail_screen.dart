// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppCustomTokens space/shell bottom reserve via TopHeader/Scaffold.
// Reference: legacy ShuiScreens.kt AccountDetailScreen (2615) dispatcher.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/account_session.dart';
import '../widgets/shui_header.dart';
import 'shower798_account_detail.dart';
import 'ujing_account_detail.dart';
import 'zhuli_account_detail.dart';

/// 账号详情子页（P2/P3）。按 [kind] 分发 Zhuli / Ujing / Shower798 登录表单。
class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    required this.kind,
    required this.state,
    required this.nowMillis,
    required this.onBack,
    required this.onLoginZhuli,
    required this.onBindDeviceCode,
    required this.onCheckZhuli,
    required this.onRequestUjingCaptcha,
    required this.onLoginUjing,
    required this.onCheckUjing,
    required this.onRequestShower798Captcha,
    required this.onSendShower798Sms,
    required this.onLoginShower798,
    required this.onAddShower798Device,
    required this.onRefreshShower798Devices,
    required this.onSelectShower798Device,
    super.key,
  });

  final AccountKind kind;
  final ShuiHomeState state;

  /// 当前 clock 毫秒（用于从 state 里的「验证码已发送时刻」恢复 cooldown 剩余）。
  final int nowMillis;
  final VoidCallback onBack;
  final void Function(String phone, String password) onLoginZhuli;
  final ValueChanged<String> onBindDeviceCode;
  final VoidCallback onCheckZhuli;
  final ValueChanged<String> onRequestUjingCaptcha;
  final void Function(String phone, String captcha) onLoginUjing;
  final VoidCallback onCheckUjing;
  final VoidCallback onRequestShower798Captcha;
  final void Function(String phone, String imageCaptcha) onSendShower798Sms;
  final void Function(String phone, String smsCode) onLoginShower798;
  final ValueChanged<String> onAddShower798Device;
  final VoidCallback onRefreshShower798Devices;
  final ValueChanged<String> onSelectShower798Device;

  String get _title => switch (kind) {
        AccountKind.zhuli => '住理生活',
        AccountKind.ujing => 'U净账号',
        AccountKind.shower798 => '慧生活798',
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: _title, showBack: true, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: switch (kind) {
                AccountKind.zhuli => ZhuliAccountDetail(
                    state: state,
                    onLogin: onLoginZhuli,
                    onBindDeviceCode: onBindDeviceCode,
                    onCheckStatus: onCheckZhuli,
                  ),
                AccountKind.ujing => UjingAccountDetail(
                    state: state,
                    nowMillis: nowMillis,
                    onRequestCaptcha: onRequestUjingCaptcha,
                    onLogin: onLoginUjing,
                    onCheckStatus: onCheckUjing,
                  ),
                AccountKind.shower798 => Shower798AccountDetail(
                    state: state,
                    nowMillis: nowMillis,
                    onRequestCaptcha: onRequestShower798Captcha,
                    onSendSms: onSendShower798Sms,
                    onLogin: onLoginShower798,
                    onAddDevice: onAddShower798Device,
                    onRefreshDevices: onRefreshShower798Devices,
                    onSelectDevice: onSelectShower798Device,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
