// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/device sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.6；legacy ShuiScreens.kt DevicesScreen/EmptyDevicesScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../runtime/models/local_device.dart';
import '../theme/shui_assets.dart';
import '../widgets/bottom_peek_character.dart';
import '../widgets/shui_animated_list.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'device_list_item.dart';

/// 计算列表中设备的展示名（自定义名优先，否则按类型 + 序号兜底）。
/// 对齐 legacy `deviceDisplayName`。
String deviceDisplayName(LocalDeviceShortcut device, int index) {
  if (device.customName.trim().isNotEmpty) {
    return device.customName;
  }
  final seq = (index + 1).toString().padLeft(2, '0');
  return switch (device.deviceType) {
    LocalDeviceType.drinkingWater => '饮水机A-$seq',
    LocalDeviceType.shower798 => '慧生活798A-$seq',
    _ => '洗衣机A-$seq',
  };
}

/// Devices 标签页：本地设备列表 + 刷新 + 添加入口。
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({
    required this.state,
    required this.onAdd,
    required this.onBack,
    required this.onRefresh,
    required this.onOpenDevice,
    required this.onMenu,
    super.key,
  });

  final ShuiHomeState state;
  final VoidCallback onAdd;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final ValueChanged<LocalDeviceShortcut> onOpenDevice;
  final ValueChanged<LocalDeviceShortcut> onMenu;

  @override
  Widget build(BuildContext context) {
    final devices = state.visibleDevices;
    final busy = state.devicesRefreshing;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopHeader(
                title: '选择设备',
                showBack: true,
                showAdd: true,
                onAdd: onAdd,
                onBack: onBack,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppCustomTokens.spaceMd,
                    AppCustomTokens.spaceSm,
                    AppCustomTokens.spaceMd,
                    bottomPeekReserve(context),
                  ),
                  child: Column(
                    children: [
                      RefreshBar(
                        lastRefreshed: state.localDevicesLastRefreshed.isEmpty
                            ? '未刷新'
                            : state.localDevicesLastRefreshed,
                        busy: busy,
                        onRefresh: onRefresh,
                      ),
                      const SizedBox(height: AppCustomTokens.spaceSm),
                      if (state.devicesRefresh.message != null) ...[
                        RuntimeStatusBanner(status: state.devicesRefresh),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                      ],
                      if (state.devicesNotice.message != null) ...[
                        RuntimeStatusBanner(status: state.devicesNotice),
                        const SizedBox(height: AppCustomTokens.spaceSm),
                      ],
                      if (state.devicesSaving) const Text('正在保存设备列表…'),
                      ShuiAnimatedList<LocalDeviceShortcut>(
                        items: devices,
                        identity: (device) => device.incarnation,
                        empty: const EmptyDeviceRuntimeCard(),
                        itemBuilder: (device, index) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppCustomTokens.spaceSm,
                            ),
                            child: DeviceListItem(
                              key: ObjectKey(device.incarnation),
                              device: device,
                              displayName: deviceDisplayName(device, index),
                              index: index,
                              onOpen: () => onOpenDevice(device),
                              onMenu: () => onMenu(device),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const BottomPeekCharacter(),
        ],
      ),
    );
  }
}

/// 空设备引导页（独立路由 EmptyDevicesRoute）。对齐 legacy `EmptyDevicesScreen`。
class EmptyDevicesView extends StatelessWidget {
  const EmptyDevicesView({
    required this.onBack,
    required this.onAdd,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopHeader(
                title: '选择设备',
                showBack: true,
                showAdd: true,
                onBack: onBack,
                onAdd: onAdd,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppCustomTokens.spaceMd,
                    AppCustomTokens.spaceSm,
                    AppCustomTokens.spaceMd,
                    bottomPeekReserve(context),
                  ),
                  child: Column(
                    children: [
                      RefreshBar(
                        lastRefreshed: '未刷新',
                        onRefresh: onBack,
                      ),
                      const SizedBox(height: AppCustomTokens.spaceLg),
                      SizedBox(
                        height: AppCustomTokens.emptyStateHeight,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecorativeImage(
                                ShuiAssets.emptyBox,
                                size: AppCustomTokens.emptyBoxSize,
                              ),
                              Text(
                                '暂无设备',
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.deepText,
                                ),
                              ),
                              const SizedBox(height: AppCustomTokens.spaceSm),
                              Text(
                                '点击右上角 + 添加设备',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
