// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/device sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.6 Devices；legacy ShuiComponents.kt DeviceListItem / RefreshBar.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/local_device.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';

/// 单台本地设备列表项。对齐 legacy `DeviceListItem`：
/// 左侧设备图（58dp）+ 中间名称/设备号/类型 + 右侧 StatusPill + 操作圆点。
class DeviceListItem extends StatelessWidget {
  const DeviceListItem({
    required this.device,
    required this.displayName,
    required this.index,
    required this.onOpen,
    required this.onMenu,
    super.key,
  });

  final LocalDeviceShortcut device;
  final String displayName;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  String get _typeLabel {
    return switch (device.deviceType) {
      LocalDeviceType.drinkingWater => '饮水快捷入口',
      LocalDeviceType.washer => device.storeName ?? '洗衣快捷入口',
      LocalDeviceType.shower798 => '慧生活798设备',
      LocalDeviceType.unknown => '本地快捷入口',
    };
  }

  Color get _statusColor {
    if (device.deviceType == LocalDeviceType.drinkingWater) {
      return AppColors.serviceBlue;
    }
    final status = device.lastStatus;
    if (status == '可下单') {
      return AppColors.serviceGreen;
    }
    if (status != null && status.contains('运行')) {
      return AppColors.serviceBlue;
    }
    return AppColors.serviceOrange;
  }

  String get _icon {
    return switch (device.deviceType) {
      LocalDeviceType.drinkingWater => ShuiAssets.shuiJieshui,
      LocalDeviceType.washer ||
      LocalDeviceType.unknown =>
        ShuiAssets.washerMachine,
      LocalDeviceType.shower798 => ShuiAssets.washerMachine,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecorativeImage(_icon, size: AppCustomTokens.deviceListIconSize),
          const SizedBox(width: AppCustomTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  // P2：设备名允许两行，避免与 icon + StatusPill + 菜单抢宽被裁。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.deviceListLineGap),
                Text(
                  '设备号：${device.deviceNo ?? _shortId(device.id)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.deviceListLineGap),
                Text(
                  _typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppCustomTokens.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                text: device.lastStatus ?? '未知',
                color: _statusColor,
                filled: true,
              ),
              const SizedBox(height: AppCustomTokens.spaceMd),
              ShuiPressable(
                onTap: onMenu,
                child: Container(
                  key: ValueKey('device-dot-$index'),
                  width: AppCustomTokens.deviceActionDotSize,
                  height: AppCustomTokens.deviceActionDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: AppCustomTokens.deviceActionDotStroke,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortId(String id) =>
      id.length <= 12 ? id : '${id.substring(0, 8)}...';
}

/// 顶部刷新条。对齐 legacy `RefreshBar`：WeakPink 底 + 圆角 + 最近刷新时间 + 「↻ 刷新」。
class RefreshBar extends StatelessWidget {
  const RefreshBar({
    required this.lastRefreshed,
    required this.onRefresh,
    this.busy = false,
    super.key,
  });

  final String lastRefreshed;
  final VoidCallback onRefresh;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return ShuiPressable(
      soft: true,
      enabled: !busy,
      onTap: onRefresh,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceMd,
          vertical: AppCustomTokens.spaceSm + AppCustomTokens.strokeThin,
        ),
        decoration: BoxDecoration(
          color:
              AppColors.weakPink.withValues(alpha: AppCustomTokens.alphaMuted),
          borderRadius: BorderRadius.circular(AppCustomTokens.radiusCompact),
          border: Border.all(
            color: AppColors.cardBorder.withValues(
              alpha: AppCustomTokens.alphaOverlay,
            ),
            width: AppCustomTokens.strokeThin,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.refresh,
              size: AppCustomTokens.navIconSize,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppCustomTokens.spaceSm),
            Expanded(
              child: Text(
                '最近刷新：$lastRefreshed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.deepText,
                ),
              ),
            ),
            Text(
              busy ? '刷新中…' : '↻ 刷新',
              style: textTheme.labelMedium?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表内空态卡（设备数为 0 但仍展示列表骨架时使用）。
class EmptyDeviceRuntimeCard extends StatelessWidget {
  const EmptyDeviceRuntimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          '暂无设备，点击右上角 + 添加设备',
          textAlign: TextAlign.center,
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}
