// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors primary/surface palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.2 HomeScreen ScanCard.

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';

class ScanCard extends StatelessWidget {
  const ScanCard({required this.onScan, super.key});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          SectionTitle(icon: ShuiAssets.shuiScancode, title: '扫码使用'),
          const SizedBox(height: AppCustomTokens.sectionGap),
          ShuiPressable(
            onTap: onScan,
            // 问题4：人物需突出到粉色面板上边界之外（legacy offset y=-24），
            // 故外层 Stack 用 Clip.none 允许溢出，人物锚 TopEnd 负 offset。
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topRight,
              children: [
                Container(
                  height: AppCustomTokens.scanPanelHeight,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.weakPink
                        .withValues(alpha: AppCustomTokens.alphaMuted),
                    borderRadius: BorderRadius.circular(
                      AppCustomTokens.radiusLarge,
                    ),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: AppCustomTokens.strokeThin,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: AppCustomTokens.scanBatStartOffset,
                        top: AppCustomTokens.spaceSm,
                        child: DecorativeImage(
                          ShuiAssets.shuiBianfu,
                          size: AppCustomTokens.scanBatSize,
                          opacity: AppCustomTokens.alphaShadow,
                        ),
                      ),
                      Center(
                        child: DecorativeImage(
                          ShuiAssets.scan,
                          width: AppCustomTokens.scanImageSizeLarge +
                              AppCustomTokens.scanBatSize,
                          height: AppCustomTokens.scanImageSizeLarge,
                        ),
                      ),
                      Positioned(
                        bottom: AppCustomTokens.spaceSm +
                            AppCustomTokens.spaceXs / 2,
                        child: Text(
                          '扫描饮水机或洗衣机二维码',
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: AppColors.deepText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 人物突出右上角（legacy: 104dp，x=-10 内收、y=-24 上探）+ 脚下椭圆地面影。
                Positioned(
                  right: AppCustomTokens.spaceSm + AppCustomTokens.spaceXs / 2,
                  top: -AppCustomTokens.spaceLg,
                  child: ShadowedImage(
                    asset: ShuiAssets.scanCharacter,
                    size: AppCustomTokens.scanCharacterHeroSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
