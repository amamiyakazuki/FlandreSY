// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (serviceBlue/deepText/mutedText), AppTypography.textTheme,
// AppCustomTokens space/radius/stroke/alpha/profile sizing.
// Reference: legacy ShuiComponents.kt AccountCard (733+) + §4.7 ProfileScreen U净 card.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../widgets/shui_components.dart';
import 'profile_widgets.dart';

/// 账号卡（P1 骨架版，U净/Blue accent）。展示 logo + 未登录占位 + 服务行 +
/// 三个迷你动作。点击均走 [onOpen] 占位（完整验证码登录在 P2 实现）。
/// 对齐 legacy `AccountCard`（标题行 + 账号摘要子卡）。
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.title,
    required this.accent,
    required this.titleIcon,
    required this.logo,
    required this.serviceIcon,
    required this.loginHint,
    required this.serviceText,
    required this.onOpen,
    this.statusTitle = '未登录',
    super.key,
  });

  final String title;
  final Color accent;
  final String titleIcon;
  final String logo;
  final String serviceIcon;
  final String loginHint;
  final String serviceText;
  final VoidCallback onOpen;

  /// 账号状态主标题（已登录：手机号 / 未登录）。默认未登录。
  final String statusTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: onOpen,
      borderColor: accent.withValues(alpha: AppCustomTokens.alphaAccent),
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusCompact,
        vertical: AppCustomTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecorativeImage(titleIcon, size: AppCustomTokens.navIconSize),
              const SizedBox(width: AppCustomTokens.spaceSm),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
              ),
              const SizedBox(width: AppCustomTokens.spaceXs),
              Text(
                '✦',
                style: textTheme.bodyMedium?.copyWith(
                  color: accent.withValues(alpha: AppCustomTokens.alphaShadow),
                ),
              ),
              const Spacer(),
              Container(
                width: AppCustomTokens.accountDividerWidth,
                height: AppCustomTokens.strokeThin,
                color: accent.withValues(alpha: AppCustomTokens.alphaSubtle),
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.sectionGap),
          Container(
            padding: const EdgeInsets.all(AppCustomTokens.spaceSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
              border: Border.all(
                color: accent.withValues(alpha: AppCustomTokens.alphaBorder),
                width: AppCustomTokens.strokeThin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DecorativeImage(logo, size: AppCustomTokens.accountLogoSize),
                    const SizedBox(width: AppCustomTokens.radiusCompact),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            // P2：账号状态标题允许两行，避免被登录按钮挤裁。
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.deepText,
                            ),
                          ),
                          Text(
                            loginHint,
                            // P2：登录提示允许两行不裁。
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
                    SizedBox(
                      width: AppCustomTokens.accountLoginButtonWidth,
                      child: PrimaryGradientButton(
                        label: statusTitle.startsWith('已登录') ? '已登录' : '点击登录',
                        compact: true,
                        onTap: onOpen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppCustomTokens.spaceSm),
                ProfileServiceRow(
                  iconAsset: serviceIcon,
                  text: serviceText,
                  accent: accent,
                  onTap: onOpen,
                ),
                const SizedBox(height: AppCustomTokens.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppCustomTokens.spaceSm,
                    vertical: AppCustomTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppCustomTokens.radiusMedium),
                    border: Border.all(
                      color: accent
                          .withValues(alpha: AppCustomTokens.alphaPopup),
                      width: AppCustomTokens.strokeThin,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ProfileMiniAction(
                        label: '重新登录',
                        glyph: '↻',
                        accent: accent,
                        onTap: onOpen,
                      ),
                      ProfileMiniAction(
                        label: '验证码登录',
                        glyph: '⌁',
                        accent: accent,
                        onTap: onOpen,
                      ),
                      ProfileMiniAction(
                        label: '查看状态',
                        glyph: '◫',
                        accent: accent,
                        onTap: onOpen,
                      ),
                    ],
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
