// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
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
      child: Container(
        height: AppCustomTokens.categoryChipHeight,
        decoration: BoxDecoration(
          color: selected
              ? color
              : AppColors.surface.withValues(alpha: AppCustomTokens.alphaCard),
          borderRadius: BorderRadius.circular(AppCustomTokens.categoryChipRadius),
          border: Border.all(
            color: color.withValues(alpha: AppCustomTokens.alphaAccent),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecorativeImage(iconAsset, size: AppCustomTokens.categoryChipIconSize),
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

/// 订单列表项（图标+类型+StatusPill / 时间+设备+金额+›）。对齐 legacy OrderListItem。
class OrderListItem extends StatelessWidget {
  const OrderListItem({required this.order, super.key});

  final OrderRowUi order;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: order.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecorativeImage(
                order.iconAsset,
                size: AppCustomTokens.orderItemIconSize,
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              // P2：type 原无 maxLines/overflow，长类型会溢出；改 Flexible + ellipsis 让位给 pill。
              Flexible(
                child: Text(
                  order.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      textTheme.titleMedium?.copyWith(color: AppColors.deepText),
                ),
              ),
              const Spacer(),
              StatusPill(text: order.status, color: order.statusColor, filled: true),
            ],
          ),
          const SizedBox(height: AppCustomTokens.orderItemRowGap),
          Row(
            children: [
              Text(
                order.time,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
              ),
              const SizedBox(width: AppCustomTokens.spaceLg),
              Expanded(
                child: Text(
                  order.device,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
                ),
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              Text(
                order.amount,
                style: textTheme.titleSmall?.copyWith(color: AppColors.deepText),
              ),
              const SizedBox(width: AppCustomTokens.spaceSm),
              if (order.onTap != null)
                Text(
                  '›',
                  style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
                ),
            ],
          ),
        ],
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
