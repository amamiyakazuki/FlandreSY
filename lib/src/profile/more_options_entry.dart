// Design tokens used: AppColors (primary/primaryLight/onPrimary), AppCustomTokens radius/navIcon/account logo sizing.
// Reference: legacy ShuiScreens.kt MoreOptionsEntry (1660-1681) + §4.7.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import 'profile_widgets.dart';

/// 更多选项入口。对齐 legacy `MoreOptionsEntry`：盾牌图标 + 标题/副标题 + ›。
/// 盾牌放进与账号中心 logo 同大小的红色圆角方块，两张卡同为实心方块图标。
class MoreOptionsEntry extends StatelessWidget {
  const MoreOptionsEntry({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ProfileEntryCard(
      onTap: onOpen,
      title: '更多选项',
      subtitle: '权限检测、日志与诊断、导入导出',
      leading: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusSmall),
        ),
        child: Center(
          child: DecorativeImage(
            ShuiAssets.shuiRed1,
            size: AppCustomTokens.navIconSize,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
