// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (primary/deepText/mutedText), AppTypography.textTheme,
// AppCustomTokens space/radius/navIcon sizing.
// Reference: legacy ShuiScreens.kt MoreOptionsEntry (1660-1681) + §4.7.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';

/// 更多选项入口（P1 骨架）。点击走 [onOpen] 占位（MoreOptionsScreen 后置）。
/// 对齐 legacy `MoreOptionsEntry`：红 1 图标 + 标题/副标题 + ›。
class MoreOptionsEntry extends StatelessWidget {
  const MoreOptionsEntry({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.radiusMedium,
      ),
      child: Row(
        children: [
          DecorativeImage(ShuiAssets.shuiRed1, size: AppCustomTokens.navIconSize),
          const SizedBox(width: AppCustomTokens.radiusCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '更多选项',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                Text(
                  '权限检测、日志与诊断、导入导出',
                  // P2：固定长副标题允许两行，避免被裁成「…导入导…」。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '›',
            style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
