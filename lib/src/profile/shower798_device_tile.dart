// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors (primary/serviceGreen/serviceOrange/cardBorder/deepText/mutedText),
// AppTypography.textTheme, AppCustomTokens space/radius/stroke/alpha.
// Reference: legacy ShuiScreens.kt Shower798AccountDetail device list item.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/account_session.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';

/// 798 设备列表项：名称/设备号/状态 + StatusPill；点击选为当前设备。
/// 对齐 legacy Shower798AccountDetail 内的设备 SectionCard。
class Shower798DeviceTile extends StatelessWidget {
  const Shower798DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.onSelect,
    super.key,
  });

  final Shower798DeviceUi device;
  final bool isCurrent;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final pillColor = isCurrent
        ? AppColors.primary
        : (device.lastStatus == '空闲'
            ? AppColors.serviceGreen
            : AppColors.serviceOrange);
    return ShuiPressable(
      onTap: onSelect,
      soft: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.radiusMedium,
          vertical: AppCustomTokens.radiusMedium,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: AppColors.cardBorder
                .withValues(alpha: AppCustomTokens.alphaOverlay),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    // P2：设备名允许两行，避免与右侧 StatusPill 抢宽被裁。
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall
                        ?.copyWith(color: AppColors.deepText),
                  ),
                  Text(
                    '设备号：${device.id} · 状态：${device.lastStatus}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppCustomTokens.spaceSm),
            StatusPill(
              text: isCurrent ? '当前设备' : device.lastStatus,
              color: pillColor,
              filled: isCurrent || device.lastStatus == '使用中',
            ),
          ],
        ),
      ),
    );
  }
}
