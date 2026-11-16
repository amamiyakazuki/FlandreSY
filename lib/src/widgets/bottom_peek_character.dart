// Design tokens used: AppCustomTokens bottom bar / character sizing, alpha.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../theme/shui_assets.dart';
import 'shui_components.dart';

/// 列表页底部预留高度：底栏 + 安全区 + 底部人物的空间，保证最后一项不被人物挡住。
double bottomPeekReserve(BuildContext context) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return AppCustomTokens.bottomBarHeight +
      bottomInset +
      AppCustomTokens.bottomCharacterContentPadding;
}

/// 从底栏探出头的芙兰（order_bottom_character），放在页面 Stack 的最上层。
/// 「卡在」底栏与页面背景的交界：下半压在波浪底栏上，上半在背景上。对齐 legacy：
/// 底 padding 比底栏总高矮约 20dp（48 + navBottom < 68 + navBottom），
/// 再 offset(x=+14, y=+6) 微调。
class BottomPeekCharacter extends StatelessWidget {
  const BottomPeekCharacter({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: AppCustomTokens.bottomCharacterSeamPadding + bottomInset,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: const Offset(
              AppCustomTokens.spaceMd - AppCustomTokens.spaceXs / 2,
              AppCustomTokens.spaceXs + AppCustomTokens.spaceXs / 2,
            ),
            child: DecorativeImage(
              ShuiAssets.orderBottomCharacter,
              size: AppCustomTokens.bottomCharacterSize,
              opacity: AppCustomTokens.alphaNearOpaque,
            ),
          ),
        ),
      ),
    );
  }
}
