// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens order/chip sizing/radius.
// Reference: legacy ShuiComponents.kt OrderListItem (664) + ShuiScreens.kt CategoryChip (2206).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../orders/order_models.dart';
import '../theme/shui_motion.dart';
import 'shui_components.dart';

/// 分类切换 chip（选中实色白字）。对齐 legacy CategoryChip。
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.text,
    required this.selected,
    required this.color,
    required this.iconAsset,
    required this.onTap,
    super.key,
  });

  final String text;
  final bool selected;
  final Color color;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return ShuiPressable(
      soft: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: ShuiMotion.duration(context, ShuiMotion.local),
        height: AppCustomTokens.categoryChipHeight,
        decoration: BoxDecoration(
          color: selected
              ? color
              : AppColors.surface.withValues(alpha: AppCustomTokens.alphaCard),
          borderRadius:
              BorderRadius.circular(AppCustomTokens.categoryChipRadius),
          border: Border.all(
            color: color.withValues(alpha: AppCustomTokens.alphaAccent),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 选中时底色就是图标的颜色，图标改成白色，和文字一致。
            DecorativeImage(
              iconAsset,
              size: AppCustomTokens.categoryChipIconSize,
              color: selected ? AppColors.onPrimary : null,
            ),
            const SizedBox(width: AppCustomTokens.spaceXs),
            Text(
              text,
              maxLines: 1,
              style: textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.deepText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 订单列表项：左边图标，中间标题 + 时间，右边金额 + 状态（右对齐），可点击的带 ›。
class OrderListItem extends StatelessWidget {
  const OrderListItem({required this.order, super.key});

  final OrderRowUi order;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: order.onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            DecorativeImage(
              order.iconAsset,
              size: AppCustomTokens.orderItemIconSize,
            ),
            const SizedBox(width: AppCustomTokens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium
                        ?.copyWith(color: AppColors.deepText),
                  ),
                  if (order.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppCustomTokens.spaceXs),
                    Text(
                      order.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppCustomTokens.spaceSm),
            // 右栏贴右边；窄屏、大字号或超长状态时最多占 45% 宽度并换行，内容完整显示。
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.amount.isNotEmpty) ...[
                    Text(
                      order.amount,
                      textAlign: TextAlign.end,
                      style: textTheme.titleSmall
                          ?.copyWith(color: AppColors.deepText),
                    ),
                    const SizedBox(height: AppCustomTokens.spaceXs),
                  ],
                  StatusPill(
                    text: order.status,
                    color: order.statusColor,
                    filled: true,
                    maxLines: null,
                  ),
                ],
              ),
            ),
            if (order.onTap != null) ...[
              const SizedBox(width: AppCustomTokens.spaceXs),
              Text(
                '›',
                style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 订单空态卡（标题 + 可选说明）。对齐 legacy EmptyOrder*State。
class EmptyOrderState extends StatelessWidget {
  const EmptyOrderState({required this.title, this.detail, super.key});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(color: AppColors.deepText),
          ),
          if (detail != null) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}
