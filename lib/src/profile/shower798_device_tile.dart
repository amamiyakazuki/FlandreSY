// Design tokens used: AppColors (primary/serviceGreen/serviceOrange/cardBorder/deepText/mutedText),
// AppTypography.textTheme, AppCustomTokens space/radius/stroke/alpha.
// Reference: legacy ShuiScreens.kt Shower798AccountDetail device list item.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/account_session.dart';
import '../theme/shui_motion.dart';
import '../widgets/device_status_label.dart';

/// 798 设备列表项：名称/设备号/单行短状态；点击选为当前设备。
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
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final pillColor = isCurrent
        ? AppColors.primary
        : (device.displayStatus == '空闲'
            ? AppColors.serviceGreen
            : AppColors.mutedText);
    return ShuiPressable(
      enabled: onSelect != null,
      onTap: onSelect ?? () {},
      soft: true,
      child: AnimatedContainer(
        duration: ShuiMotion.duration(context, ShuiMotion.local),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.radiusMedium,
          vertical: AppCustomTokens.radiusMedium,
        ),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primary
                  .withValues(alpha: AppCustomTokens.alphaVeryLow)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
          border: Border.all(
            color: AppColors.cardBorder
                .withValues(alpha: AppCustomTokens.alphaOverlay),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(color: AppColors.deepText),
            ),
            Text(
              '设备号：${device.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
            DeviceStatusLabel(
              label: isCurrent
                  ? '当前设备'
                  : compactDeviceStatus(device.displayStatus),
              details:
                  '${device.name}\n设备号：${device.id}\n状态：${device.displayStatus}',
              color: pillColor,
            ),
          ],
        ),
      ),
    );
  }
}
