// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/shell sizing.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';

class AdaptivePhoneContainer extends StatelessWidget {
  const AdaptivePhoneContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppCustomTokens.adaptivePhoneMaxWidth,
          ),
          child: ColoredBox(color: AppColors.background, child: child),
        ),
      ),
    );
  }
}

class DecorativeImage extends StatelessWidget {
  const DecorativeImage(
    this.asset, {
    this.size,
    this.width,
    this.height,
    this.opacity = 1,
    this.fit = BoxFit.contain,
    this.color,
    super.key,
  });

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final double opacity;
  final BoxFit fit;

  /// 非空时把图标整体染成这个颜色（保留透明度轮廓），用于实色背景上的图标。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: width ?? size,
        height: height ?? size,
        fit: fit,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(
      AppCustomTokens.spaceMd - AppCustomTokens.spaceXs,
    ),
    this.borderColor = AppColors.cardBorder,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.softPink.withValues(alpha: AppCustomTokens.alphaEmphasis),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
        border: Border.all(
          color: borderColor,
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return card;
    }
    return ShuiPressable(onTap: onTap!, soft: true, child: card);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    required this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Row(
      children: [
        DecorativeImage(icon, size: AppCustomTokens.navIconSize),
        const SizedBox(width: AppCustomTokens.spaceSm),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
        ),
        const SizedBox(width: AppCustomTokens.spaceSm),
        DecorativeImage(
          ShuiAssets.shuiThreeStar,
          size: AppCustomTokens.statusIconSize - AppCustomTokens.spaceXs,
          opacity: AppCustomTokens.alphaMuted,
        ),
        const SizedBox(width: AppCustomTokens.spaceXs),
        if (trailing != null)
          Expanded(
            child: Text(
              trailing!,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          )
        else
          const Expanded(child: _SectionTitleDecoration()),
      ],
    );
  }
}

class _SectionTitleDecoration extends StatelessWidget {
  const _SectionTitleDecoration();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: AppCustomTokens.strokeThin,
            color: AppColors.cardBorder.withValues(
              alpha: AppCustomTokens.alphaMuted,
            ),
          ),
        ),
        const SizedBox(width: AppCustomTokens.spaceXs),
        DecorativeImage(
          ShuiAssets.shuiCloud,
          size: AppCustomTokens.spaceLg - AppCustomTokens.spaceXs,
          opacity: AppCustomTokens.alphaDisabled,
        ),
        const SizedBox(width: AppCustomTokens.spaceXs),
        Expanded(
          child: Container(
            height: AppCustomTokens.strokeThin,
            color: AppColors.cardBorder.withValues(
              alpha: AppCustomTokens.alphaMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final button = Container(
      height: compact
          ? AppCustomTokens.compactActionHeight
          : AppCustomTokens.primaryActionHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppCustomTokens.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? const [
                  AppColors.primaryLight,
                  AppColors.primary,
                  AppColors.primaryDark,
                ]
              : [
                  AppColors.outline
                      .withValues(alpha: AppCustomTokens.alphaMuted),
                  AppColors.outline
                      .withValues(alpha: AppCustomTokens.alphaDisabled),
                ],
        ),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
        border: Border.all(
          color:
              AppColors.onPrimary.withValues(alpha: AppCustomTokens.alphaMuted),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: AppColors.onPrimary,
              size: AppCustomTokens.spaceMd,
            ),
            const SizedBox(width: AppCustomTokens.spaceXs),
          ],
          Flexible(
            child: AnimatedSwitcher(
              duration: ShuiMotion.duration(context, ShuiMotion.local),
              child: Text(
                label,
                key: ValueKey(label),
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.labelLarge?.copyWith(color: AppColors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
    return ShuiPressable(enabled: enabled, onTap: onTap, child: button);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.text,
    required this.color,
    this.filled = false,
    this.maxLines = 2,
    super.key,
  });

  final String text;
  final Color color;
  final bool filled;

  /// null = 不限行数，完整显示（订单记录里的状态必须看全）。
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      // P2 截断修复：去掉旧的 maxWidth:126 硬限（状态串超 ~5-6 汉字即被裁）。
      // 改为一个宽松的命名上限仅防极端超长；默认让 pill 按内容 + 父级约束自适应，
      // 状态是必须看清的信息，宁可换行不可裁字（配合下方 maxLines:2 + softWrap）。
      constraints: const BoxConstraints(
        maxWidth: AppCustomTokens.statusPillMaxWidth,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.spaceSm,
        vertical: AppCustomTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: AppCustomTokens.alphaChip)
            : AppColors.surface
                .withValues(alpha: AppCustomTokens.alphaNearOpaque),
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusSmall),
        border: Border.all(
          color: color.withValues(alpha: AppCustomTokens.alphaSoftBorder),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Text(
        text,
        // P2：允许两行 + softWrap，状态串通常 ≤ 8 字两行足够；仍保 ellipsis 防极端。
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        maxLines: maxLines,
        softWrap: true,
        style: AppTypography.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class RuntimeStatusBanner extends StatelessWidget {
  const RuntimeStatusBanner({required this.status, super.key});

  final RuntimeActionStatus status;

  @override
  Widget build(BuildContext context) {
    final message = status.message;
    final color = switch (status.state) {
      RuntimeTaskState.success => AppColors.serviceGreen,
      RuntimeTaskState.failure ||
      RuntimeTaskState.loginRequired ||
      RuntimeTaskState.permissionRequired =>
        AppColors.serviceOrange,
      _ => AppColors.primary,
    };
    return AnimatedSize(
      duration: ShuiMotion.duration(context, ShuiMotion.local),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: ShuiMotion.duration(context, ShuiMotion.normal),
        switchInCurve: ShuiMotion.easeOut,
        switchOutCurve: ShuiMotion.easeIn,
        child: message == null || message.isEmpty
            ? const SizedBox(key: ValueKey('empty-status'))
            : Container(
                key: ValueKey(message),
                width: double.infinity,
                padding: const EdgeInsets.all(AppCustomTokens.spaceSm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: AppCustomTokens.alphaLow),
                  borderRadius:
                      BorderRadius.circular(AppCustomTokens.radiusMedium),
                  border: Border.all(
                    color: color.withValues(alpha: AppCustomTokens.alphaShadow),
                    width: AppCustomTokens.strokeThin,
                  ),
                ),
                child: Text(
                  message,
                  style: AppTypography.textTheme.bodyMedium
                      ?.copyWith(color: color),
                ),
              ),
      ),
    );
  }
}

/// 信息行：定宽 label + 可省略 value。对齐 legacy `InfoLine`（饮水/订单详情常用）。
class InfoLine extends StatelessWidget {
  const InfoLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppCustomTokens.infoLineLabelWidth,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ),
        Expanded(
          // P2 截断修复：value 常载金额/设备号/ID（如「金额 ¥8.00」），
          // 允许两行 + softWrap 避免被裁；仍保 ellipsis 作极端兜底。
          child: Text(
            value,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
        ),
      ],
    );
  }
}

/// 人物在图片里的落脚位置（按图片宽高的比例），用来把地面影子放到脚下。
/// 数值按图片里双脚的实际像素位置测得。
@immutable
class CharacterFootprint {
  const CharacterFootprint({
    required this.centerX,
    required this.feetY,
    required this.width,
  });

  /// 双脚中点的横向位置。
  final double centerX;

  /// 鞋底所在的纵向位置。
  final double feetY;

  /// 影子宽度（含双脚两侧的余量）。
  final double width;

  /// 热水人物：左侧是水龙头，脚在偏右的位置。
  static const hotWater =
      CharacterFootprint(centerX: 0.59, feetY: 0.96, width: 0.44);

  /// 扫码人物：脚在偏左的位置，图片底部留有空白。
  static const scan =
      CharacterFootprint(centerX: 0.446, feetY: 0.918, width: 0.42);
}

/// 带地面影子的人物图：影子是脚下的扁椭圆，双脚踩在影子中间。
class ShadowedImage extends StatelessWidget {
  const ShadowedImage({
    required this.asset,
    required this.size,
    required this.footprint,
    super.key,
  });

  final String asset;
  final double size;
  final CharacterFootprint footprint;

  @override
  Widget build(BuildContext context) {
    final shadowWidth = size * footprint.width;
    final shadowHeight = size * 0.11;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size * footprint.centerX - shadowWidth / 2,
            // 影子中线略高于鞋底，鞋子看起来踩在影子上。
            top: size * footprint.feetY - shadowHeight * 0.6,
            width: shadowWidth,
            height: shadowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardBorder.withValues(
                  alpha: AppCustomTokens.alphaShadow,
                ),
                borderRadius: BorderRadius.all(
                    Radius.elliptical(shadowWidth / 2, shadowHeight / 2)),
              ),
            ),
          ),
          DecorativeImage(asset, size: size),
        ],
      ),
    );
  }
}
