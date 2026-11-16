// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/stroke/device sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.6 Devices；legacy ShuiComponents.kt DeviceListItem / RefreshBar.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/local_device.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/shui_components.dart';
import '../widgets/device_status_label.dart';

/// 单台本地设备列表项。对齐 legacy `DeviceListItem`：
/// 左侧设备图 + 中间名称 /「设备号 · 宿舍」/ 短状态 + 右侧「⋯」管理按钮。
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

  /// 「设备号 · 宿舍」。「扫码添加」只是来源说明，不算宿舍，不显示。
  String get _infoLine {
    final store = device.storeName?.trim() ?? '';
    return [
      device.deviceNo ?? _shortId(device.id),
      if (store.isNotEmpty && store != '扫码添加') store,
    ].join(' · ');
  }

  Color get _statusColor {
    if (device.deviceType == LocalDeviceType.drinkingWater) {
      return AppColors.serviceBlue;
    }
    if (device.statusQueryFailed) return AppColors.serviceOrange;
    if (!device.statusConfirmed) return AppColors.mutedText;
    final status = compactDeviceStatus(device.lastStatus);
    if (status == '可下单') {
      return AppColors.serviceGreen;
    }
    if (status == '运行中' || status == '使用中') {
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
                  // 状态位于下方，名称不再与长状态争夺横向空间。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.deepText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.deviceListLineGap),
                Text(
                  _infoLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: AppCustomTokens.deviceListLineGap),
                DeviceStatusLabel(
                  label: device.statusQueryFailed
                      ? '查询失败'
                      : device.statusConfirmed
                          ? compactDeviceStatus(device.lastStatus)
                          : device.lastStatus == null
                              ? '未查询'
                              : '待核对',
                  details:
                      '$displayName\n设备号：${device.deviceNo ?? device.id}\n${device.statusQueryFailed ? '本次查询失败；上次结果：${device.lastStatus ?? '未知'}' : device.statusConfirmed ? '${device.lastStatus ?? '未知'}（查询于 ${device.statusCheckedAt}）' : device.lastStatus == null ? '状态未查询' : '上次结果：${device.lastStatus}（未核对）'}',
                  color: _statusColor,
                ),
              ],
            ),
          ),
          // 红圈里放「⋯」，表明这是「更多操作」（编辑 / 删除），不是单选框。
          // 点击区域比圆圈大一圈，方便点中。
          Semantics(
            button: true,
            label: '管理设备',
            child: ShuiPressable(
              onTap: onMenu,
              child: SizedBox.square(
                key: ValueKey('device-dot-$index'),
                dimension: AppCustomTokens.deviceActionDotSize +
                    2 * AppCustomTokens.spaceSm,
                child: Center(
                  child: Container(
                    width: AppCustomTokens.deviceActionDotSize,
                    height: AppCustomTokens.deviceActionDotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: AppCustomTokens.deviceActionDotStroke,
                      ),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      size: AppCustomTokens.deviceActionDotSize -
                          2 * AppCustomTokens.deviceActionDotStroke -
                          AppCustomTokens.spaceXs / 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortId(String id) =>
      id.length <= 12 ? id : '${id.substring(0, 8)}...';
}

/// 顶部刷新条。对齐 legacy `RefreshBar`：WeakPink 底 + 圆角 + 最近刷新时间 + 「刷新」。
class RefreshBar extends StatelessWidget {
  const RefreshBar({
    required this.lastRefreshed,
    required this.onRefresh,
    this.busy = false,
    super.key,
  });

  /// 最近一次成功刷新的时间（HH:mm）；空串表示还没刷新过。
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
                lastRefreshed.isEmpty ? '尚未刷新' : '最近刷新：$lastRefreshed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.deepText,
                ),
              ),
            ),
            Text(
              busy ? '刷新中…' : '刷新',
              style: textTheme.labelMedium?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表内空态：空箱子插画 +「暂无设备」+ 添加提示（与独立空设备页一致）。
class EmptyDeviceRuntimeCard extends StatelessWidget {
  const EmptyDeviceRuntimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppCustomTokens.spaceLg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecorativeImage(
              ShuiAssets.emptyBox,
              size: AppCustomTokens.emptyBoxSize,
            ),
            Text(
              '暂无设备',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.deepText,
              ),
            ),
            const SizedBox(height: AppCustomTokens.spaceSm),
            Text(
              '点击右上角 + 添加设备',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
