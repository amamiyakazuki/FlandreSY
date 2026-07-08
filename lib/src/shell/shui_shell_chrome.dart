// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors shell palette, AppTypography.textTheme, AppCustomTokens bottom/header/icon/spacing.
//
// Shell「外壳装饰」组件集合：底栏、开场动画、权限对话框、占位页。
// 从 shui_shell.dart 抽出，让 Shell 专注路由编排，避免 God 文件（对齐 Module A 拆分纪律）。

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import '../widgets/shui_painters.dart';
import 'shui_shell.dart';

/// 波浪底部导航栏（4 个主 Tab + 蝙蝠装饰 + 安全区处理）。
class WavyBottomBar extends StatelessWidget {
  const WavyBottomBar({
    required this.selectedTab,
    required this.onTabSelected,
    super.key,
  });

  final MainTab selectedTab;
  final ValueChanged<MainTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: AppCustomTokens.bottomBarHeight + bottomInset,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: AppCustomTokens.bottomBarHeight,
            child: CustomPaint(
              painter: const _BottomBarPainter(),
              child: Stack(
                children: [
                  Positioned(
                    right: AppCustomTokens.bottomBarReservedHeight,
                    top: AppCustomTokens.spaceSm,
                    child: DecorativeImage(
                      ShuiAssets.shuiBianfu,
                      size: AppCustomTokens.compactActionHeight,
                      opacity: AppCustomTokens.alphaDisabled,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppCustomTokens.spaceLg,
                      right: AppCustomTokens.spaceLg,
                      top: AppCustomTokens.spaceSm,
                      bottom: AppCustomTokens.spaceXs,
                    ),
                    child: Row(
                      children: MainTab.values.map((tab) {
                        final selected = tab == selectedTab;
                        return Expanded(
                          child: ShuiPressable(
                            soft: true,
                            onTap: () => onTabSelected(tab),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ShuiLineIcon(
                                  name: tab.iconName,
                                  color: AppColors.onPrimary.withValues(
                                    alpha: selected
                                        ? 1
                                        : AppCustomTokens.alphaDisabled,
                                  ),
                                  size: AppCustomTokens.navIconSizeLarge,
                                ),
                                Text(
                                  tab.label,
                                  style: AppTypography.textTheme.labelSmall
                                      ?.copyWith(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: selected
                                          ? 1
                                          : AppCustomTokens.alphaMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBarPainter extends CustomPainter {
  const _BottomBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, AppCustomTokens.bottomBarWaveTop);
    var x = 0.0;
    final wave = size.width / 18;
    while (x + wave < size.width) {
      path.quadraticBezierTo(
        x + wave / 2,
        0,
        x + wave,
        AppCustomTokens.bottomBarWaveTop,
      );
      x += wave;
    }
    path
      ..lineTo(size.width, AppCustomTokens.bottomBarWaveTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    const gradient = LinearGradient(
      colors: [
        AppColors.primaryLight,
        AppColors.primary,
        AppColors.primaryDark,
      ],
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 开场动画（home_top_character 缩放 + 标题 + 副标题）。
class OpeningMotionOverlay extends StatelessWidget {
  const OpeningMotionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // 透明 Material：开场层作为 Shell Stack 兄弟渲染，需 Material 祖先避免文本黄色双下划线。
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: AppColors.background,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: ShuiMotion.opening,
            curve: ShuiMotion.easeOut,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecorativeImage(
                  ShuiAssets.homeTopCharacter,
                  size: AppCustomTokens.headerCharacterSize,
                ),
                const SizedBox(height: AppCustomTokens.spaceSm),
                Text(
                  '芙兰水衣',
                  style: AppTypography.textTheme.displayLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '水、衣、热水，轻轻开始',
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 首次启动权限引导对话框（sleep 插图 + 说明 + 开启权限）。
class FirstLaunchPermissionDialog extends StatelessWidget {
  const FirstLaunchPermissionDialog({required this.onConfirm, super.key});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // 透明 Material：本对话框作为 Shell Stack 的兄弟渲染（无 Scaffold 祖先），
    // 需 Material 祖先，否则文本出现黄色双下划线（route 页各自有 Scaffold，不受影响）。
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: AppColors.scrim.withValues(alpha: AppCustomTokens.alphaOverlay),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppCustomTokens.spaceXl,
            ),
            child: SectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecorativeImage(
                    ShuiAssets.sleep,
                    size: AppCustomTokens.dialogImageSize,
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  Text(
                    '先给小助手一点权限吧',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      color: AppColors.deepText,
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  Text(
                    '扫码相机、热水蓝牙、蓝牙扫描定位都需要系统权限。点一下我就会一次性申请，之后就不用反复打扰你啦。',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceMd),
                  PrimaryGradientButton(label: '好，开启权限', onTap: onConfirm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 尚未实现模块的占位页（Orders / Profile 等）。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.body,
    this.showSettings = false,
    this.showAdd = false,
    super.key,
  });

  final String title;
  final String body;
  final bool showSettings;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: title, showSettings: showSettings, showAdd: showAdd),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: SectionCard(
                child: Center(
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
