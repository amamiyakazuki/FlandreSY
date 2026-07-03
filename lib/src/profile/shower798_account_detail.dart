// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius/captcha/sms sizing.
// Reference: P_PLAN/...Reference.md §4.8 §5.4 + legacy ShuiScreens.kt Shower798AccountDetail (2800).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_text_field.dart';
import 'shower798_device_tile.dart';

/// 慧生活798 登录详情（图形验证码 base64 刷新 + 短信 cooldown + 设备管理）。
/// 图片解码/刷新链路真实（Image.memory），数据 fake。真实短信/账号登录留用户真机验证。
class Shower798AccountDetail extends StatefulWidget {
  const Shower798AccountDetail({
    required this.state,
    required this.nowMillis,
    required this.onRequestCaptcha,
    required this.onSendSms,
    required this.onLogin,
    required this.onAddDevice,
    required this.onRefreshDevices,
    required this.onSelectDevice,
    super.key,
  });

  final ShuiHomeState state;

  /// 当前 clock 毫秒。短信 cooldown 从 state.shower798CaptchaSentAtMillis 按真实经过时间恢复，
  /// 不再依赖 widget 局部标志 → 离开/返回详情页不会把 cooldown 重置回 30s。
  final int nowMillis;
  final VoidCallback onRequestCaptcha;
  final void Function(String phone, String imageCaptcha) onSendSms;
  final void Function(String phone, String smsCode) onLogin;
  final ValueChanged<String> onAddDevice;
  final VoidCallback onRefreshDevices;
  final ValueChanged<String> onSelectDevice;

  @override
  State<Shower798AccountDetail> createState() => _Shower798AccountDetailState();
}

class _Shower798AccountDetailState extends State<Shower798AccountDetail> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.state.shower798Account?.mobile ?? '');
  final TextEditingController _imageCaptcha = TextEditingController();
  final TextEditingController _smsCode = TextEditingController();
  final TextEditingController _deviceId = TextEditingController();

  int _cooldown = 0;
  Timer? _cooldownTimer;
  int _syncedSentAt = 0;
  bool _requestedInitialCaptcha = false;

  @override
  void initState() {
    super.initState();
    // 进入自动请求图形验证码 + 查看状态（对齐 legacy LaunchedEffect(Unit)）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requestedInitialCaptcha &&
          widget.state.shower798CaptchaImageBase64 == null) {
        _requestedInitialCaptcha = true;
        widget.onRequestCaptcha();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phone.dispose();
    _imageCaptcha.dispose();
    _smsCode.dispose();
    _deviceId.dispose();
    super.dispose();
  }

  /// 从 state 的「短信已发送时刻」按真实经过时间 seed cooldown，再交本地 Timer 每秒递减。
  /// 每个 sentAt 只 seed 一次（_syncedSentAt 守卫），避免每帧重新 seed 顶回递减。
  /// 修「离开→返回详情页重置 30s」，同时保持 golden 确定性递减。同 U净 detail。
  void _syncCooldown() {
    final sentAt = widget.state.shower798CaptchaSentAtMillis;
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
    final captchaBusy = s.shower798Captcha.isBusy;
    final loginBusy = s.shower798Login.isBusy;
    return Column(
      children: [
        _LoginCard(
          state: s,
          phone: _phone,
          imageCaptcha: _imageCaptcha,
          smsCode: _smsCode,
          captchaBusy: captchaBusy,
          loginBusy: loginBusy,
          cooldown: _cooldown,
          onRefreshCaptcha: widget.onRequestCaptcha,
          onSendSms: () => widget.onSendSms(_phone.text, _imageCaptcha.text),
          onLogin: () => widget.onLogin(_phone.text, _smsCode.text),
        ),
        const SizedBox(height: AppCustomTokens.sectionGap),
        _DeviceCard(
          state: s,
          deviceId: _deviceId,
          loginBusy: loginBusy,
          onAdd: () {
            widget.onAddDevice(_deviceId.text);
            _deviceId.clear();
          },
          onRefresh: widget.onRefreshDevices,
          onSelect: widget.onSelectDevice,
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.state,
    required this.phone,
    required this.imageCaptcha,
    required this.smsCode,
    required this.captchaBusy,
    required this.loginBusy,
    required this.cooldown,
    required this.onRefreshCaptcha,
    required this.onSendSms,
    required this.onLogin,
  });

  final ShuiHomeState state;
  final TextEditingController phone;
  final TextEditingController imageCaptcha;
  final TextEditingController smsCode;
  final bool captchaBusy;
  final bool loginBusy;
  final int cooldown;
  final VoidCallback onRefreshCaptcha;
  final VoidCallback onSendSms;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: ShuiAssets.shuiHuisheng798, title: '慧生活798登录'),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          RuntimeStatusBanner(status: state.shower798Login),
          if (state.shower798Captcha.message != null) ...[
            const SizedBox(height: AppCustomTokens.spaceXs),
            RuntimeStatusBanner(status: state.shower798Captcha),
          ],
          const SizedBox(height: AppCustomTokens.formFieldGap),
          ShuiTextField(
            controller: phone,
            label: '手机号',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          Text(
            '图形验证码',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          _CaptchaBox(
            base64Image: state.shower798CaptchaImageBase64,
            busy: captchaBusy,
            onTap: onRefreshCaptcha,
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          ShuiTextField(controller: imageCaptcha, label: '输入图形验证码'),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          Row(
            children: [
              Expanded(
                child: PrimaryGradientButton(
                  label: captchaBusy
                      ? '发送中'
                      : (cooldown > 0 ? '等待${cooldown}s' : '发送验证码'),
                  enabled: !captchaBusy && cooldown == 0,
                  compact: true,
                  onTap: onSendSms,
                ),
              ),
              const SizedBox(width: AppCustomTokens.formFieldGap),
              Expanded(
                child: PrimaryGradientButton(
                  label: '刷新图片',
                  enabled: !captchaBusy,
                  compact: true,
                  onTap: onRefreshCaptcha,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          ShuiTextField(
            controller: smsCode,
            label: '短信验证码',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          PrimaryGradientButton(
            label: loginBusy ? '登录中' : '登录慧生活798',
            enabled: !loginBusy,
            onTap: onLogin,
          ),
        ],
      ),
    );
  }
}

/// 图形验证码框：有 base64 时用 Image.memory 真实渲染，否则占位「点击刷新」。
class _CaptchaBox extends StatelessWidget {
  const _CaptchaBox({
    required this.base64Image,
    required this.busy,
    required this.onTap,
  });

  final String? base64Image;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        height: AppCustomTokens.captchaBoxHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface
              .withValues(alpha: AppCustomTokens.alphaEmphasis),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppCustomTokens.strokeThin,
          ),
        ),
        alignment: Alignment.center,
        child: base64Image != null
            ? Padding(
                padding:
                    const EdgeInsets.all(AppCustomTokens.captchaBoxPadding),
                child: Image.memory(
                  base64Decode(base64Image!),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              )
            : Text(
                '点击刷新图形验证码',
                style:
                    textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.state,
    required this.deviceId,
    required this.loginBusy,
    required this.onAdd,
    required this.onRefresh,
    required this.onSelect,
  });

  final ShuiHomeState state;
  final TextEditingController deviceId;
  final bool loginBusy;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final devices = state.shower798Devices;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: ShuiAssets.shuiHuisheng798, title: '慧生活798设备'),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          Text(
            '登录后会自动刷新设备列表。先选择默认洗浴系统，再在这里指定当前使用的 798 设备。',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          ShuiTextField(controller: deviceId, label: '输入设备号后添加'),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          Row(
            children: [
              Expanded(
                child: PrimaryGradientButton(
                  label: '添加设备',
                  enabled: !loginBusy,
                  compact: true,
                  onTap: onAdd,
                ),
              ),
              const SizedBox(width: AppCustomTokens.formFieldGap),
              Expanded(
                child: PrimaryGradientButton(
                  label: '刷新列表',
                  enabled: !loginBusy,
                  compact: true,
                  onTap: onRefresh,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.formFieldGap),
          if (devices.isEmpty)
            Text(
              '暂无慧生活798设备',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            )
          else
            ...devices.map(
              (device) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppCustomTokens.spaceSm),
                child: Shower798DeviceTile(
                  device: device,
                  isCurrent: state.currentShower798DeviceId == device.id,
                  onSelect: () => onSelect(device.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
