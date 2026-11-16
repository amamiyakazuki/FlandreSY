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
          // 左边是数字和操作（上下排列），右边是人物，两边高度相近、垂直居中。
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShuiPressable(
                      onTap: onWasherSummary,
                      soft: true,
                      child: _WasherMetricsPanel(
                        washerCount: washerCount,
                        availableCount: availableCount,
                      ),
                    ),
                    const SizedBox(height: AppCustomTokens.spaceSm),
                    PrimaryGradientButton(
                      label: '选择设备 ›',
                      compact: true,
                      onTap: onOpenDevices,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              // 原图是横向的（人物 + 洗衣机），按宽度给尺寸，不留上下空白。
              DecorativeImage(
                ShuiAssets.washerCharacter,
                width: AppCustomTokens.washerCharacterSizeLarge +
                    AppCustomTokens.spaceSm,
                height: (AppCustomTokens.washerCharacterSizeLarge +
                        AppCustomTokens.spaceSm) *
                    652 /
                    869,
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
