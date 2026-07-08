// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens option sizing/radius/alpha.
// Reference: legacy ShuiComponents.kt OptionCard (549) + ShuiScreens.kt OptionSection (1375).

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_motion.dart';
import 'shui_components.dart';

/// 单个选项模型：标题 + 可选副标题（价格）+ 图标资产 + 图标色。
class OptionItem {
  const OptionItem({
    required this.title,
    this.subtitle,
    this.iconAsset,
    required this.iconColor,
  });

  final String title;
  final String? subtitle;
  final String? iconAsset;
  final Color iconColor;
}

/// 通用选项卡（对齐 legacy OptionCard）。选中蓝/主色边 + 右下 ✓ 角标（带副标题时）。
/// 供套餐/温度/洗衣液/除菌液等多处复用。
class OptionCard extends StatelessWidget {
  const OptionCard({
    required this.item,
    required this.selected,
    required this.accent,
    super.key,
  });

  final OptionItem item;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final hasSubtitle = item.subtitle != null;
    final labelColor = selected ? accent : AppColors.deepText;
    return Container(
      height: hasSubtitle
          ? AppCustomTokens.optionCardTallHeight
          : AppCustomTokens.optionCardHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: AppCustomTokens.alphaVeryLow)
            : AppColors.surface.withValues(alpha: AppCustomTokens.alphaMuted),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        border: Border.all(
          color: selected
              ? accent
              : AppColors.cardBorder
                  .withValues(alpha: AppCustomTokens.alphaMuted),
          width: AppCustomTokens.optionStroke,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppCustomTokens.spaceXs + 2,
                vertical: AppCustomTokens.spaceXs,
              ),
              child: hasSubtitle
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.iconAsset != null) ...[
                          DecorativeImage(
                            item.iconAsset!,
                            size: AppCustomTokens.optionCardIconLarge,
                          ),
                          const SizedBox(height: 1),
                        ],
                        // P2 截断修复：标题/副标题（价格）用 FittedBox 等比缩放，
                        // 避免窄格（OptionSection 等宽 1/4 分格）里被 ellipsis 裁掉。
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                textTheme.titleSmall?.copyWith(color: labelColor),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: selected ? accent : AppColors.mutedText,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.iconAsset != null) ...[
                          DecorativeImage(
                            item.iconAsset!,
                            size: AppCustomTokens.optionCardIconSize,
                          ),
                          const SizedBox(width: AppCustomTokens.spaceXs + 1),
                        ],
                        // P2 截断修复：短标签（常温/30°C）用 FittedBox 缩放，
                        // 避免在 1/4 宽格 + 前置 icon 抢宽时被裁成「常…」。
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: labelColor),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (selected && hasSubtitle)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: AppCustomTokens.optionCheckSize,
                height: AppCustomTokens.optionCheckSize,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppCustomTokens.radiusMedium),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '✓',
                  style: textTheme.labelSmall?.copyWith(color: AppColors.onPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 选项分组（SectionTitle + 一行等宽 OptionCard）。对齐 legacy OptionSection。
class OptionSection extends StatelessWidget {
  const OptionSection({
    required this.iconAsset,
    required this.title,
    required this.tail,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final String iconAsset;
  final String title;
  final String tail;
  final List<OptionItem> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.radiusCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(icon: iconAsset, title: title, trailing: tail),
          const SizedBox(height: AppCustomTokens.radiusCompact),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: AppCustomTokens.spaceSm),
                Expanded(
                  child: ShuiPressable(
                    soft: true,
                    onTap: () => onSelected(i),
                    child: OptionCard(
                      item: options[i],
                      selected: i == selectedIndex,
                      accent: options[i].iconColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
