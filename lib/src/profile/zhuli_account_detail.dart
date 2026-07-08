// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius.
// Reference: P_PLAN/...Reference.md §4.8 + legacy ShuiScreens.kt ZhuliAccountDetail (2643).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_text_field.dart';

/// 住理生活登录详情（手机号 + 密码 → 登录；设备码绑定）。
/// 表单本地态用 StatefulWidget（对齐 legacy remember），提交走 runtime action。
class ZhuliAccountDetail extends StatefulWidget {
  const ZhuliAccountDetail({
    required this.state,
    required this.onLogin,
    required this.onBindDeviceCode,
    required this.onCheckStatus,
    super.key,
  });

  final ShuiHomeState state;
  final void Function(String phone, String password) onLogin;
  final ValueChanged<String> onBindDeviceCode;
  final VoidCallback onCheckStatus;

  @override
  State<ZhuliAccountDetail> createState() => _ZhuliAccountDetailState();
}

class _ZhuliAccountDetailState extends State<ZhuliAccountDetail> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.state.zhuli.phone);
  final TextEditingController _password = TextEditingController();
  late final TextEditingController _deviceCode =
      TextEditingController(text: widget.state.zhuli.deviceCode);

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _deviceCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final busy = s.hotwaterLogin.isBusy;
    final loggedIn = s.zhuli.isLoggedIn &&
        s.hotwaterLogin.state != RuntimeTaskState.loginRequired;
    return Column(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: ShuiAssets.shuiZhuli, title: '住理生活'),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              RuntimeStatusBanner(status: s.hotwaterLogin),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              ShuiTextField(
                controller: _phone,
                label: '手机号',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              ShuiTextField(
                controller: _password,
                label: '密码',
                obscureText: true,
              ),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              PrimaryGradientButton(
                label: busy ? '登录中' : (loggedIn ? '已登录' : '点击登录'),
                enabled: !busy,
                onTap: () => widget.onLogin(_phone.text, _password.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppCustomTokens.sectionGap),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: ShuiAssets.shuiFire, title: '绑定设备码'),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              ShuiTextField(controller: _deviceCode, label: '热水设备码'),
              const SizedBox(height: AppCustomTokens.formFieldGap),
              Row(
                children: [
                  Expanded(
                    child: PrimaryGradientButton(
                      label: '绑定设备码',
                      compact: true,
                      onTap: () => widget.onBindDeviceCode(_deviceCode.text),
                    ),
                  ),
                  const SizedBox(width: AppCustomTokens.formFieldGap),
                  Expanded(
                    child: PrimaryGradientButton(
                      label: '查看状态',
                      compact: true,
                      onTap: widget.onCheckStatus,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppCustomTokens.spaceSm),
              Text(
                '当前设备码：${s.zhuli.deviceCode.isEmpty ? '未绑定' : s.zhuli.deviceCode}',
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
