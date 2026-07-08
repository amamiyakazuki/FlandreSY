// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens
// space/profile sizing/shell bottom reserve. Thin composition (cards live in own files).
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.7 + legacy ProfileScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'account_card.dart';
import 'bath_system_card.dart';
import 'more_options_entry.dart';

/// Profile「我的」页（P1 骨架）。核心可跑通锚点：洗浴系统切换 → Home 热水卡联动 + 持久化。
/// 账号登录细节为占位（onOpenAccount / onOpenMore 触发提示），完整流程留 P2/P3。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.state,
    required this.onSwitchBathSystem,
    required this.onOpenBathAccount,
    required this.onOpenUjing,
    required this.onOpenMore,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onSwitchBathSystem;
  final VoidCallback onOpenBathAccount;
  final VoidCallback onOpenUjing;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(
            title: '我的',
            showSettings: true,
            onSettings: onOpenMore,
            character: Positioned(
              left: AppCustomTokens.dialogMarginWide,
              bottom: -AppCustomTokens.spaceXs,
              child: DecorativeImage(
                ShuiAssets.profileTopCharacter,
                size: AppCustomTokens.profileTopCharacterSize,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceSm,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: Column(
                children: [
                  BathSystemEntryCard(
                    state: state,
                    onSwitchBathSystem: onSwitchBathSystem,
                    onOpenAccount: onOpenBathAccount,
                  ),
                  const SizedBox(height: AppCustomTokens.sectionGap),
                  AccountCard(
                    title: 'U净账号',
                    accent: AppColors.serviceBlue,
                    titleIcon: ShuiAssets.shuiU,
                    logo: ShuiAssets.shuiU,
                    serviceIcon: ShuiAssets.shuiBlueCheck,
                    loginHint: '验证码登录 U净',
                    serviceText: '检测 U净服务',
                    statusTitle: state.ujingAccount != null
                        ? '已登录：${state.ujingAccount!.mobile}'
                        : '未登录',
                    onOpen: onOpenUjing,
                  ),
                  const SizedBox(height: AppCustomTokens.sectionGap),
                  MoreOptionsEntry(onOpen: onOpenMore),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  _ProfileBottomDecor(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部大装饰（shui_wode_bottom）。对齐 legacy 86dp 容器 + 258dp 图。
class _ProfileBottomDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppCustomTokens.profileBottomDecorHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecorativeImage(
          ShuiAssets.profileBottom,
          size: AppCustomTokens.profileBottomDecorSize,
          opacity: AppCustomTokens.alphaNearOpaque,
        ),
      ),
    );
  }
}
