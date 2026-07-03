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
    required this.onOpenHotwaterDetail,
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
  final VoidCallback onOpenHotwaterDetail;
  final VoidCallback onScan;
  final VoidCallback onWasherSummary;
  final VoidCallback onSwitchBathSystem;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(
            title: '芙兰水衣',
            showSettings: true,
            onSettings: onOpenProfile,
            character: Positioned(
              left: AppCustomTokens.spaceMd,
              bottom: -AppCustomTokens.spaceXs,
              child: DecorativeImage(
                ShuiAssets.homeTopCharacter,
                size: AppCustomTokens.headerCharacterSize,
              ),
            ),
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
                  RuntimeStatusBanner(status: state.waterScan),
                  const SizedBox(height: AppCustomTokens.sectionGap),
                  HotWaterCard(
                    state: state,
                    onStartHotwater: onStartHotwater,
                    onStopHotwater: onStopHotwater,
                    onSwitchBathSystem: onSwitchBathSystem,
                    onOpenDetail: onOpenHotwaterDetail,
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
    );
  }
}
