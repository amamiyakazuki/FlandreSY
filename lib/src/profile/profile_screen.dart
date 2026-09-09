// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens
// space/profile sizing/shell bottom reserve. Thin composition (cards live in own files).
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.7 + legacy ProfileScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'more_options_entry.dart';

/// Profile「我的」页（P1 骨架）。核心可跑通锚点：洗浴系统切换 → Home 热水卡联动 + 持久化。
/// 账号登录细节为占位（onOpenAccount / onOpenMore 触发提示），完整流程留 P2/P3。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.state,
    required this.onOpenAccountHub,
    required this.onOpenMore,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onOpenAccountHub;
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
                  SectionCard(
                    onTap: onOpenAccountHub,
                    padding: const EdgeInsets.all(AppCustomTokens.spaceMd),
                    child: Row(
                      children: [
                        DecorativeImage(
                          ShuiAssets.shuiZhuli,
                          size: AppCustomTokens.accountLogoSize,
                        ),
                        const SizedBox(width: AppCustomTokens.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '账号中心',
                                style: AppTypography.textTheme.titleMedium
                                    ?.copyWith(color: AppColors.deepText),
                              ),
                              Text(
                                '管理住理生活、慧生活798、U净账号',
                                style: AppTypography.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '›',
                          style: AppTypography.textTheme.titleLarge
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
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
