// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors header gradient, AppTypography.textTheme, AppCustomTokens header/spacing/icon sizing.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import 'shui_components.dart';
import 'shui_painters.dart';

class TopHeader extends StatelessWidget {
  const TopHeader({
    required this.title,
    this.showBack = false,
    this.showSettings = false,
    this.showAdd = false,
    this.character,
    this.onBack,
    this.onSettings,
    this.onAdd,
    super.key,
  });

  final String title;
  final bool showBack;
  final bool showSettings;
  final bool showAdd;
  final Widget? character;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final titleStyle = title.length <= 3
        ? AppTypography.textTheme.displayMedium
        : AppTypography.textTheme.headlineLarge;
    return SizedBox(
      height: AppCustomTokens.topHeaderHeight,
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                  AppColors.primaryLight,
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          if (character != null) character!,
          Align(
            child: Padding(
              padding: const EdgeInsets.only(top: AppCustomTokens.spaceXs),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: titleStyle?.copyWith(color: AppColors.onPrimary),
              ),
            ),
          ),
          if (showBack)
            _HeaderIconButton(
              alignment: Alignment.centerLeft,
              label: '‹',
              onTap: onBack ?? () {},
            ),
          if (showSettings)
            _HeaderIconButton(
              alignment: Alignment.centerRight,
              label: '⚙',
              onTap: onSettings ?? () {},
            ),
          if (showAdd)
            _HeaderIconButton(
              alignment: Alignment.centerRight,
              label: '+',
              onTap: onAdd ?? () {},
            ),
          Positioned(
            left: AppCustomTokens.bottomBarReservedHeight,
            bottom: AppCustomTokens.spaceLg,
            child: DecorativeImage(
              ShuiAssets.shuiHeart,
              size: AppCustomTokens.spaceLg,
              opacity: AppCustomTokens.alphaMuted,
            ),
          ),
          Positioned(
            right: AppCustomTokens.bottomBarReservedHeight,
            top: AppCustomTokens.spaceLg,
            child: DecorativeImage(
              ShuiAssets.shuiHeart,
              size: AppCustomTokens.spaceXl,
              opacity: AppCustomTokens.alphaDisabled,
            ),
          ),
          const Align(alignment: Alignment.bottomCenter, child: HeaderWave()),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.alignment,
    required this.label,
    required this.onTap,
  });

  final Alignment alignment;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceLg,
        ),
        child: ShuiPressable(
          onTap: onTap,
          child: Text(
            label,
            style: AppTypography.textTheme.headlineLarge?.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
