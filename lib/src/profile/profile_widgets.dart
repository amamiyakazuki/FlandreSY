// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/profile sizing.
// Reference: legacy ShuiScreens.kt AccountServiceRow / AccountMiniAction.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';

/// 「我的」页入口卡：方块图标 + 标题/副标题 + ›。账号中心与更多选项共用，
/// 保证图标大小、字号、内边距和箭头位置一致。
class ProfileEntryCard extends StatelessWidget {
  const ProfileEntryCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  /// 方块图标，放在 [AppCustomTokens.accountLogoSize] 见方的位置里。
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppCustomTokens.spaceMd),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppCustomTokens.accountLogoSize,
            child: leading,
          ),
          const SizedBox(
              width: AppCustomTokens.spaceSm + AppCustomTokens.spaceXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium
                      ?.copyWith(color: AppColors.deepText),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          Text(
            '›',
            style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// 账号服务行（bordered row：图标 + 文案 + ›）。对齐 legacy `AccountServiceRow`。
class ProfileServiceRow extends StatelessWidget {
  const ProfileServiceRow({
    required this.iconAsset,
    required this.text,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String iconAsset;
  final String text;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShuiPressable(
      onTap: onTap,
      soft: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceMd - AppCustomTokens.spaceXs,
          vertical: AppCustomTokens.spaceSm + AppCustomTokens.spaceXs / 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: AppColors.cardBorder
                .withValues(alpha: AppCustomTokens.alphaPopup),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Row(
          children: [
            DecorativeImage(iconAsset,
                size: AppCustomTokens.accountSmallIconSize),
            const SizedBox(
                width: AppCustomTokens.spaceSm + AppCustomTokens.spaceXs / 2),
            Expanded(
              child: Text(
                text,
                // P2：信息行允许两行不裁。
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepText,
                ),
              ),
            ),
            Text(
              '›',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账号迷你动作（竖排：字形 + 标签）。对齐 legacy `AccountMiniAction`。
class ProfileMiniAction extends StatelessWidget {
  const ProfileMiniAction({
    required this.label,
    required this.glyph,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String label;
  final String glyph;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShuiPressable(
      onTap: onTap,
      soft: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceXs,
          vertical: AppCustomTokens.spaceXs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              glyph,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: accent,
              ),
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            // P2：窄 chip 内短标签用 FittedBox 缩放不裁。
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
