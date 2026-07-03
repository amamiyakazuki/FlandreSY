// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (primary/serviceOrange/serviceBlue/deepText/mutedText),
// AppTypography.textTheme, AppCustomTokens space/radius/stroke/alpha/profile sizing.
// Reference: legacy ShuiScreens.kt BathSystemEntryCard (1540-1659) + §4.7 ProfileScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import 'profile_widgets.dart';

/// 洗浴系统切换卡（P1 核心）。展示当前系统 + Switch 切换（影响 Home 热水卡），
/// 当前账号摘要为骨架（未登录占位，完整登录 P2/P3）。
/// 对齐 legacy `BathSystemEntryCard`：标题行 + 当前系统子卡 + 账号摘要子卡。
class BathSystemEntryCard extends StatelessWidget {
  const BathSystemEntryCard({
    required this.state,
    required this.onSwitchBathSystem,
    required this.onOpenAccount,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onSwitchBathSystem;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final useShower798 =
        state.bathSystemPreference == BathSystemPreference.shower798;
    final accent =
        useShower798 ? AppColors.serviceOrange : AppColors.primary;

    return SectionCard(
      borderColor:
          AppColors.primary.withValues(alpha: AppCustomTokens.alphaAccent),
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusCompact,
        vertical: AppCustomTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(title: '洗浴系统'),
          const SizedBox(height: AppCustomTokens.spaceSm),
          _CurrentSystemRow(
            useShower798: useShower798,
            onSwitch: onSwitchBathSystem,
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          _AccountSummary(
            useShower798: useShower798,
            accent: accent,
            // 住理：登录后显示手机号；798：登录后显示手机号 + 设备数摘要（P3）。
            statusTitle: _statusTitle(useShower798),
            loggedIn: useShower798
                ? state.shower798Account != null
                : state.zhuli.isLoggedIn,
            onOpenAccount: onOpenAccount,
          ),
        ],
      ),
    );
  }

  /// 账号摘要主标题：登录显手机号，否则「未登录」。
  String _statusTitle(bool useShower798) {
    if (useShower798) {
      final acc = state.shower798Account;
      return acc != null ? '已登录：${acc.mobile}' : '未登录';
    }
    return state.zhuli.isLoggedIn ? '已登录：${state.zhuli.phone}' : '未登录';
  }
}

/// 卡片标题行：fire 图标 + 标题 + ✦ + 右侧细分隔线。对齐 legacy 头部。
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecorativeImage(ShuiAssets.shuiFire, size: AppCustomTokens.navIconSize),
        const SizedBox(width: AppCustomTokens.spaceSm),
        Text(
          title,
          style: AppTypography.textTheme.titleMedium
              ?.copyWith(color: AppColors.deepText),
        ),
        const SizedBox(width: AppCustomTokens.spaceXs),
        Text(
          '✦',
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.primary
                .withValues(alpha: AppCustomTokens.alphaShadow),
          ),
        ),
        const Spacer(),
        Container(
          width: AppCustomTokens.accountDividerWidth,
          height: AppCustomTokens.strokeThin,
          color: AppColors.primary
              .withValues(alpha: AppCustomTokens.alphaSubtle),
        ),
      ],
    );
  }
}

/// 当前系统子卡：文案 + 「住理 / Switch / 惠生活」切换。
class _CurrentSystemRow extends StatelessWidget {
  const _CurrentSystemRow({required this.useShower798, required this.onSwitch});

  final bool useShower798;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.radiusCompact,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  useShower798 ? '当前使用惠生活798' : '当前使用住理生活',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                Text(
                  '点击切换默认洗浴系统',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '住理',
            style: textTheme.labelSmall?.copyWith(
              color: useShower798 ? AppColors.mutedText : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          Switch(
            value: useShower798,
            onChanged: (_) => onSwitch(),
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: AppColors.serviceOrange,
            inactiveThumbColor: AppColors.onPrimary,
            inactiveTrackColor: AppColors.primary,
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          Text(
            '惠生活',
            style: textTheme.labelSmall?.copyWith(
              color: useShower798 ? AppColors.serviceOrange : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前账号摘要子卡（住理已登录显示手机号；798 P3 占位）。
class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.useShower798,
    required this.accent,
    required this.statusTitle,
    required this.loggedIn,
    required this.onOpenAccount,
  });

  final bool useShower798;
  final Color accent;
  final String statusTitle;
  final bool loggedIn;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Container(
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
              DecorativeImage(
                useShower798
                    ? ShuiAssets.shuiHuisheng798
                    : ShuiAssets.shuiZhuli,
                size: AppCustomTokens.accountLogoSize,
              ),
              const SizedBox(width: AppCustomTokens.radiusCompact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      // P2：状态标题允许两行，避免被固定宽登录按钮挤裁。
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.deepText,
                      ),
                    ),
                    Text(
                      useShower798 ? '登录后可管理洗浴设备' : '登录后可绑定热水设备码',
                      // P2：副标题固定长句允许两行不裁。
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
                  label: loggedIn ? '已登录' : '点击登录',
                  compact: true,
                  onTap: onOpenAccount,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          ProfileServiceRow(
            iconAsset: useShower798
                ? ShuiAssets.shuiBlueCheck
                : ShuiAssets.shuiRedCheck,
            text: useShower798 ? '当前默认使用惠生活798洗浴' : '当前默认使用住理生活热水',
            accent: accent,
            onTap: onOpenAccount,
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppCustomTokens.spaceSm,
              vertical: AppCustomTokens.spaceXs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
              border: Border.all(
                color: AppColors.cardBorder
                    .withValues(alpha: AppCustomTokens.alphaOverlay),
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
                  onTap: onOpenAccount,
                ),
                _MiniDivider(accent: accent),
                ProfileMiniAction(
                  label: useShower798 ? '进入设备与登录' : '进入住理登录',
                  glyph: '⌁',
                  accent: accent,
                  onTap: onOpenAccount,
                ),
                _MiniDivider(accent: accent),
                ProfileMiniAction(
                  label: '查看状态',
                  glyph: '◫',
                  accent: accent,
                  onTap: onOpenAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  const _MiniDivider({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppCustomTokens.strokeThin,
      height: AppCustomTokens.statusIconSize - AppCustomTokens.spaceXs,
      color: accent.withValues(alpha: AppCustomTokens.alphaLow),
    );
  }
}
