// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.

import 'package:flutter/material.dart';

import '../../../design_tokens.dart';
import '../../theme/shui_assets.dart';
import '../../theme/shui_motion.dart';
import '../../widgets/shui_components.dart';

class WasherDeviceSummaryCard extends StatelessWidget {
  const WasherDeviceSummaryCard({
    required this.washerCount,
    required this.availableCount,
    required this.onOpenDevices,
    required this.onWasherSummary,
    super.key,
  });

  final int washerCount;
  final int availableCount;
  final VoidCallback onOpenDevices;
  final VoidCallback onWasherSummary;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          SectionTitle(icon: ShuiAssets.shuiYifu, title: '洗衣设备'),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ShuiPressable(
                  onTap: onWasherSummary,
                  soft: true,
                  child: _WasherMetricsPanel(
                    washerCount: washerCount,
                    availableCount: availableCount,
                  ),
                ),
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              SizedBox(
                width: AppCustomTokens.washerCharacterSizeLarge +
                    AppCustomTokens.spaceLg,
                child: Column(
                  children: [
                    // 问题5：删掉左下多余的小洗衣机图标（legacy 本无此图），
                    // 人物放大到 legacy 112dp 并居中，填满右侧空间。
                    DecorativeImage(
                      ShuiAssets.washerCharacter,
                      size: AppCustomTokens.washerCharacterSize,
                    ),
                    const SizedBox(height: AppCustomTokens.spaceXs),
                    PrimaryGradientButton(
                      label: '选择设备 ›',
                      compact: true,
                      onTap: onOpenDevices,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WasherMetricsPanel extends StatelessWidget {
  const _WasherMetricsPanel({
    required this.washerCount,
    required this.availableCount,
  });

  final int washerCount;
  final int availableCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.spaceMd,
        vertical: AppCustomTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(
          alpha: AppCustomTokens.alphaCardAlt,
        ),
        borderRadius: BorderRadius.circular(
          AppCustomTokens.radiusMedium,
        ),
        border: Border.all(
          color: AppColors.cardBorder.withValues(
            alpha: AppCustomTokens.alphaMuted,
          ),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WasherMetric(
              label: '已添加设备',
              value: '$washerCount',
              suffix: '台',
              color: AppColors.primary,
            ),
          ),
          Container(
            width: AppCustomTokens.strokeThin,
            height:
                AppCustomTokens.compactActionHeight + AppCustomTokens.spaceMd,
            color: AppColors.cardBorder.withValues(
              alpha: AppCustomTokens.alphaMuted,
            ),
          ),
          Expanded(
            child: _WasherMetric(
              label: '空闲设备',
              value: '$availableCount',
              suffix: '台',
              color: AppColors.serviceGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _WasherMetric extends StatelessWidget {
  const _WasherMetric({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  final String label;
  final String value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.deepText,
            ),
          ),
        ),
        const SizedBox(height: AppCustomTokens.spaceXs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.textTheme.displayLarge?.copyWith(
                  color: color,
                ),
              ),
              const SizedBox(width: AppCustomTokens.spaceXs),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppCustomTokens.spaceSm,
                ),
                child: Text(
                  suffix,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
