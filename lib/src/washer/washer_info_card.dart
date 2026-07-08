// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius/washer sizing.
// Reference: legacy ShuiScreens.kt WasherRuntimeInfoCard (1104) + §4.5.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/washer_order.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';

/// 洗衣机信息卡：机器图 + 名称/设备号/门店 + StatusPill（可下单绿/不可橙）。
class WasherRuntimeInfoCard extends StatelessWidget {
  const WasherRuntimeInfoCard({required this.program, super.key});

  final WasherProgramUi? program;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final p = program;
    return SectionCard(
      child: Row(
        children: [
          DecorativeImage(
            ShuiAssets.washerMachine,
            size: AppCustomTokens.washerMachineInfoSize,
          ),
          const SizedBox(width: AppCustomTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.deviceTypeName ?? '待扫码洗衣机',
                  // P2：设备类型名允许两行，避免与 StatusPill 抢宽被裁。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
                ),
                const SizedBox(height: AppCustomTokens.spaceXs),
                Text(
                  '设备号：${p?.deviceNo ?? '未识别'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                Text(
                  '门店：${p?.storeName ?? '未知门店'}',
                  // P2：门店名允许两行不裁。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          StatusPill(
            text: p == null
                ? '待扫码'
                : (p.createOrderEnabled ? '可下单' : '不可下单'),
            color: p != null && p.createOrderEnabled
                ? AppColors.serviceGreen
                : AppColors.serviceOrange,
            filled: p != null && p.createOrderEnabled,
          ),
        ],
      ),
    );
  }
}
