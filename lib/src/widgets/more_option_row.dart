// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (primary/deepText/mutedText), AppTypography.textTheme,
// AppCustomTokens space/radius/navIcon sizing.
// Reference: legacy ShuiScreens.kt MoreOptionRow (3254).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import 'shui_components.dart';

/// 更多选项列表行（图标 + 标题/副标题 + › 或自定义 trailing）。对齐 legacy MoreOptionRow。
/// [trailing] 非空时替代默认 `›`（如放置开关 Switch）；此时 [onTap] 可为 null（整行不可点）。
class MoreOptionRow extends StatelessWidget {
  const MoreOptionRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// 尾部自定义控件（如 Switch）。为 null 时显示默认 `›` chevron。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.radiusMedium,
      ),
      child: Row(
        children: [
          DecorativeImage(iconAsset, size: AppCustomTokens.navIconSize),
          const SizedBox(width: AppCustomTokens.radiusCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(color: AppColors.deepText),
                ),
                Text(
                  subtitle,
                  // P2：复用行副标题允许两行（各调用方的长副标题全体受益）。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          trailing ??
              Text(
                '›',
                style:
                    textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
        ],
      ),
    );
  }
}

/// 遮罩居中对话框卡（About / 版本检查复用）。对齐 legacy AboutDialog 遮罩布局。
class ShuiModalCard extends StatelessWidget {
  const ShuiModalCard({required this.child, required this.onDismiss, super.key});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: ColoredBox(
        color: AppColors.scrim.withValues(alpha: AppCustomTokens.alphaOverlay),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppCustomTokens.dialogMarginWide,
            ),
            // 吞掉卡片内部点击，避免误触遮罩关闭。
            child: GestureDetector(
              onTap: () {},
              child: SectionCard(
                padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
