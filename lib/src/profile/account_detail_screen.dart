// Design tokens used: AppCustomTokens space/shell bottom reserve via TopHeader/Scaffold.
// Reference: legacy ShuiScreens.kt AccountDetailScreen (2615) dispatcher.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/account_session.dart';
import '../widgets/shui_header.dart';
import '../widgets/shui_components.dart';
import 'shower798_account_detail.dart';
import 'ujing_account_detail.dart';
import 'zhuli_account_detail.dart';

/// 账号详情子页（P2/P3）。按 [kind] 分发 Zhuli / Ujing / Shower798 登录表单。
class AccountDetailScreen extends StatefulWidget {
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
    required this.onSetDefaultSystem,
    this.onCheckAccount,
    this.onLogout,
    this.accountGeneration,
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
  final ValueChanged<BathSystemPreference> onSetDefaultSystem;
  final ValueChanged<AccountKind>? onCheckAccount;
  final ValueChanged<AccountKind>? onLogout;
  final int? accountGeneration;

  Object get _accountIdentity => switch (kind) {
        AccountKind.zhuli => state.zhuli.phone.trim(),
        AccountKind.ujing => (
            state.ujingAccount?.mobile.trim(),
            state.ujingAccount?.userId
          ),
        AccountKind.shower798 => (
            state.shower798Account?.mobile.trim(),
            state.shower798Account?.uid,
            state.shower798Account?.eid
          ),
      };

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();

  String get _title => switch (kind) {
        AccountKind.zhuli => '住理生活',
        AccountKind.ujing => 'U净账号',
        AccountKind.shower798 => '慧生活798',
      };

  Widget _build(BuildContext context, VoidCallback onConfirmLogout) {
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
              child: Column(children: [
                if (onCheckAccount != null || onLogout != null) ...[
                  SectionCard(
                      child: Column(children: [
                    RuntimeStatusBanner(
                        status: state.account.availability[kind] ??
                            const RuntimeActionStatus()),
                    Row(children: [
                      if (onCheckAccount != null)
                        Expanded(
                            child: TextButton(
                                onPressed: () => onCheckAccount?.call(kind),
                                child: const Text('检测账号状态'))),
                      if (onLogout != null)
                        Expanded(
                            child: TextButton(
                                onPressed: onConfirmLogout,
                                child: const Text('退出本机登录'))),
                    ]),
                  ])),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                ],
                switch (kind) {
                  AccountKind.zhuli => ZhuliAccountDetail(
                      state: state,
                      onLogin: onLoginZhuli,
                      onBindDeviceCode: onBindDeviceCode,
                      onCheckStatus: onCheckZhuli,
                      showCheckStatus: onCheckAccount == null,
                      isDefault: state.bathSystemPreference ==
                          BathSystemPreference.zhuli,
                      onDefaultChanged: (selected) => onSetDefaultSystem(
                        selected
                            ? BathSystemPreference.zhuli
                            : BathSystemPreference.none,
                      ),
                    ),
                  AccountKind.ujing => UjingAccountDetail(
                      state: state,
                      nowMillis: nowMillis,
                      onRequestCaptcha: onRequestUjingCaptcha,
                      onLogin: onLoginUjing,
                      onCheckStatus: onCheckUjing,
                      showCheckStatus: onCheckAccount == null,
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
                      isDefault: state.bathSystemPreference ==
                          BathSystemPreference.shower798,
                      onDefaultChanged: (selected) => onSetDefaultSystem(
                        selected
                            ? BathSystemPreference.shower798
                            : BathSystemPreference.none,
                      ),
                    ),
                }
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  int _entryGeneration = 0;
  bool _logoutDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _scheduleEntryCheck();
  }

  @override
  void didUpdateWidget(AccountDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != oldWidget.kind) _scheduleEntryCheck();
  }

  void _scheduleEntryCheck() {
    final generation = ++_entryGeneration;
    final kind = widget.kind;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _entryGeneration || kind != widget.kind) {
        return;
      }
      widget.onCheckAccount?.call(kind);
    });
  }

  Future<void> _confirmLogout() async {
    if (_logoutDialogOpen) return;
    _logoutDialogOpen = true;
    final kind = widget.kind;
    final generation = _entryGeneration;
    final accountIdentity = widget._accountIdentity;
    final accountGeneration = widget.accountGeneration;
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('退出${widget._title}本机登录？'),
                content:
                    const Text('仅退出此设备上的账号登录，保留已有订单和设备记录，不会关闭真实设备或结束正在使用的服务。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确认退出')),
                ],
              ));
      if (confirmed == true &&
          mounted &&
          widget.kind == kind &&
          generation == _entryGeneration) {
        if (widget._accountIdentity != accountIdentity ||
            widget.accountGeneration != accountGeneration) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('账号状态已变化，请重新确认退出')));
          return;
        }
        widget.onLogout?.call(kind);
      }
    } finally {
      _logoutDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget._build(context, _confirmLogout);
}
