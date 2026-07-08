// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens spacing/radius/sizing/alpha.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'cards/hot_water_card.dart';
import 'cards/ongoing_card.dart';
import 'cards/scan_card.dart';
import 'cards/washer_device_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.onOpenProfile,
    required this.onOpenDevices,
    required this.onStartHotwater,
    required this.onStopHotwater,
    required this.onScan,
    required this.onWasherSummary,
    required this.onSwitchBathSystem,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDevices;
  final VoidCallback onStartHotwater;
  final VoidCallback onStopHotwater;
  final VoidCallback onScan;
  final VoidCallback onWasherSummary;
  final VoidCallback onSwitchBathSystem;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    // 问题6：人物需「半压」红白交界（header 底边）。header 与内容是 Column，若把人物
    // 塞进 header 的 Stack，向下溢出会被内容盖住/裁掉。故提到外层 Stack 顶层，定位到
    // header 底边下探 6dp（对齐 legacy home_top_character：BottomStart + offset(y=+6)）。
    final characterTop = topInset +
        AppCustomTokens.topHeaderContentHeight -
        AppCustomTokens.headerCharacterSizeSmall +
        AppCustomTokens.spaceSm - AppCustomTokens.spaceXs / 2;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopHeader(
                title: '芙兰水衣',
                showSettings: true,
                onSettings: onOpenProfile,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppCustomTokens.spaceMd,
                    AppCustomTokens.spaceSm,
                    AppCustomTokens.spaceMd,
                    bottomPadding,
                  ),
                  child: Column(
                    children: [
                      OngoingCard(tasks: state.homeTasks),
                      const SizedBox(height: AppCustomTokens.sectionGap),
                      HotWaterCard(
                        state: state,
                        onStartHotwater: onStartHotwater,
                        onStopHotwater: onStopHotwater,
                        onSwitchBathSystem: onSwitchBathSystem,
                      ),
                      const SizedBox(height: AppCustomTokens.sectionGap),
                      ScanCard(onScan: onScan),
                      const SizedBox(height: AppCustomTokens.sectionGap),
                      WasherDeviceSummaryCard(
                        washerCount: state.localWasherCount,
                        availableCount: state.availableWasherCount,
                        onOpenDevices: onOpenDevices,
                        onWasherSummary: onWasherSummary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: AppCustomTokens.spaceLg,
            top: characterTop,
            child: IgnorePointer(
              child: DecorativeImage(
                ShuiAssets.homeTopCharacter,
                size: AppCustomTokens.headerCharacterSizeSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
