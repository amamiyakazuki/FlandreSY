// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/shell sizing.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
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
    super.key,
  });

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final double opacity;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: width ?? size,
        height: height ?? size,
        fit: fit,
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
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(color: AppColors.onPrimary),
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
    super.key,
  });

  final String text;
  final Color color;
  final bool filled;

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
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
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
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = switch (status.state) {
      RuntimeTaskState.success => AppColors.serviceGreen,
      RuntimeTaskState.failure ||
      RuntimeTaskState.loginRequired ||
      RuntimeTaskState.permissionRequired =>
        AppColors.serviceOrange,
      _ => AppColors.primary,
    };
    return AnimatedSwitcher(
      duration: ShuiMotion.normal,
      switchInCurve: ShuiMotion.easeOut,
      switchOutCurve: ShuiMotion.easeIn,
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        padding: const EdgeInsets.all(AppCustomTokens.spaceSm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppCustomTokens.alphaLow),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: color.withValues(alpha: AppCustomTokens.alphaShadow),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Text(
          message,
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: color),
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

class ShadowedImage extends StatelessWidget {
  const ShadowedImage({required this.asset, required this.size, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size * 0.72,
            height: AppCustomTokens.spaceMd,
            margin: const EdgeInsets.only(bottom: AppCustomTokens.spaceXs),
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(
                alpha: AppCustomTokens.alphaShadow,
              ),
              borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
            ),
          ),
          DecorativeImage(asset, size: size),
        ],
      ),
    );
  }
}
