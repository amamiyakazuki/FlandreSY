// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.2 HomeScreen HotWaterCard.

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../runtime/fake_shui_runtime.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';
import '../../widgets/shui_painters.dart';

class HotWaterCard extends StatelessWidget {
  const HotWaterCard({
    required this.state,
    required this.onToggleHotwater,
    required this.onSwitchBathSystem,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onToggleHotwater;
  final VoidCallback onSwitchBathSystem;

  @override
  Widget build(BuildContext context) {
    final isShower798 =
        state.bathSystemPreference == BathSystemPreference.shower798;
    final busy = state.hotwaterStart.isBusy || state.hotwaterStop.isBusy;
    final statusText = state.hotwaterStart.message ?? '热水待启动';
    final warningText = state.hotwaterStart.message ?? '可在下方查看当前状态并执行操作';
    final statusColor = state.hotwaterRunning
        ? AppColors.serviceGreen
        : state.hotwaterStart.state == RuntimeTaskState.loginRequired
            ? AppColors.serviceOrange
            : AppColors.primary;

    return SectionCard(
      child: Column(
        children: [
          SectionTitle(icon: ShuiAssets.shuiFire, title: '热水控制'),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _CurrentStatusLabel(),
                    const SizedBox(height: AppCustomTokens.spaceSm),
                    AnimatedSwitcher(
                      duration: ShuiMotion.normal,
                      child: Text(
                        '≋  $statusText',
                        key: ValueKey(statusText),
                        textAlign: TextAlign.center,
                        style: AppTypography.textTheme.titleMedium?.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppCustomTokens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryGradientButton(
                            label: busy
                                ? (state.hotwaterRunning ? '关闭中' : '启动中')
                                : (isShower798 ? '开始洗浴' : '开热水'),
                            enabled: !busy,
                            onTap: onToggleHotwater,
                          ),
                        ),
                        const SizedBox(width: AppCustomTokens.spaceSm),
                        Expanded(
                          child: PrimaryGradientButton(
                            label: busy
                                ? (state.hotwaterRunning ? '关闭中' : '启动中')
                                : (isShower798 ? '结束洗浴' : '关热水'),
                            enabled: !busy,
                            onTap: onToggleHotwater,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppCustomTokens.spaceSm),
                    ShuiPressable(
                      onTap: onSwitchBathSystem,
                      soft: true,
                      child: StatusPill(
                        text: isShower798 ? '当前：慧生活798' : '当前：住理生活',
                        color: isShower798
                            ? AppColors.serviceBlue
                            : AppColors.primary,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
              ShadowedImage(
                asset: ShuiAssets.hotWaterCharacter,
                size: AppCustomTokens.hotWaterCharacterSize,
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: AppCustomTokens.alphaVeryLow),
              borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
            ),
            child: SizedBox(
              width: double.infinity,
              child: DashedBorderBox(
                color: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppCustomTokens.spaceMd,
                  vertical: AppCustomTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    Text(
                      '⚠',
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppCustomTokens.spaceSm),
                    Expanded(
                      child: Text(
                        warningText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    DecorativeImage(
                      ShuiAssets.shuiBianfu,
                      size: AppCustomTokens.scanBatSize -
                          AppCustomTokens.spaceXs / 2,
                      opacity: AppCustomTokens.alphaDisabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStatusLabel extends StatelessWidget {
  const _CurrentStatusLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: DashedRule()),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppCustomTokens.spaceSm),
          child: Text(
            '当前状态',
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.deepText,
            ),
          ),
        ),
        const Expanded(child: DashedRule()),
      ],
    );
  }
}
