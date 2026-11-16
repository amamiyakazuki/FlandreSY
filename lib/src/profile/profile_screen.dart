// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens
// space/profile sizing/shell bottom reserve. Thin composition (cards live in own files).
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.7 + legacy ProfileScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'more_options_entry.dart';
import 'profile_widgets.dart';

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
      body: Stack(
        children: [
          // 装饰放最底层：内容变多（大字号）时卡片盖在它上面，而不是被它挡住。
          const _ProfileBottomDecor(),
          Column(
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
                      ProfileEntryCard(
                        onTap: onOpenAccountHub,
                        title: '账号中心',
                        subtitle: '管理住理生活、慧生活798、U净账号',
                        leading: DecorativeImage(
                          ShuiAssets.shuiZhuli,
                          size: AppCustomTokens.accountLogoSize,
                        ),
                      ),
                      const SizedBox(height: AppCustomTokens.sectionGap),
                      MoreOptionsEntry(onOpen: onOpenMore),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 底部大装饰（shui_wode_bottom：洗衣机 + 衣篮），「坐」在波浪底栏上，
/// 与订单页、设备页底部的芙兰同一思路。图里左侧有一段透明留白，向左平移让画面居中。
class _ProfileBottomDecor extends StatelessWidget {
  const _ProfileBottomDecor();

  /// shui_wode_bottom.png 960×555，内容从 x=155 开始。
  static const double _contentShift =
      AppCustomTokens.profileBottomDecorSize * 155 / 960 / 2;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: AppCustomTokens.bottomBarHeight -
          AppCustomTokens.bottomBarWaveTop +
          bottomInset,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: const Offset(-_contentShift, 0),
            child: DecorativeImage(
              ShuiAssets.profileBottom,
              width: AppCustomTokens.profileBottomDecorSize,
              height: AppCustomTokens.profileBottomDecorSize * 555 / 960,
              opacity: AppCustomTokens.alphaNearOpaque,
            ),
          ),
        ),
      ),
    );
  }
}
