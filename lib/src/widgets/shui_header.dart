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
    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight = AppCustomTokens.topHeaderContentHeight + topInset;
    final titleStyle = AppTypography.textTheme.headlineLarge;
    return SizedBox(
      height: headerHeight,
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
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            height: AppCustomTokens.topHeaderContentHeight -
                AppCustomTokens.headerWaveHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: AppCustomTokens.spaceXs),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: titleStyle?.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: AppCustomTokens.headerTitleSize,
                  ),
                ),
              ),
            ),
          ),
          if (showBack)
            _HeaderIconButton(
              topInset: topInset,
              alignment: Alignment.centerLeft,
              iconName: 'back',
              onTap: onBack ?? () {},
            ),
          if (showSettings)
            _HeaderIconButton(
              topInset: topInset,
              alignment: Alignment.centerRight,
              iconName: 'settings',
              onTap: onSettings ?? () {},
            ),
          if (showAdd)
            _HeaderIconButton(
              topInset: topInset,
              alignment: Alignment.centerRight,
              iconName: 'add',
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
            top: topInset + AppCustomTokens.spaceMd,
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
    required this.topInset,
    required this.alignment,
    required this.iconName,
    required this.onTap,
  });

  final double topInset;
  final Alignment alignment;
  final String iconName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset,
      left: 0,
      right: 0,
      height: AppCustomTokens.topHeaderContentHeight -
          AppCustomTokens.headerWaveHeight,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppCustomTokens.spaceLg,
          ),
          child: ShuiPressable(
            key: ValueKey('header-$iconName'),
            onTap: onTap,
            child: iconName == 'settings'
                ? const Icon(
                    Icons.settings_outlined,
                    size: AppCustomTokens.headerActionIconSize,
                    color: AppColors.onPrimary,
                  )
                : ShuiLineIcon(
                    name: iconName,
                    size: AppCustomTokens.headerActionIconSize,
                    color: AppColors.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
