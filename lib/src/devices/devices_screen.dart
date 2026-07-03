// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens space/radius/device sizing/alpha.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.6；legacy ShuiScreens.kt DevicesScreen/EmptyDevicesScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/local_device.dart';
import '../theme/shui_assets.dart';
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

/// 公共底部预留高度：底栏 + 安全区 + 底部角色插画空间。
double _bottomReserve(BuildContext context) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return AppCustomTokens.bottomBarHeight +
      bottomInset +
      AppCustomTokens.bottomCharacterContentPadding;
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
    final busy = state.devicesRefresh.isBusy;
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
                    _bottomReserve(context),
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
                      if (devices.isEmpty)
                        const EmptyDeviceRuntimeCard()
                      else
                        ...devices.asMap().entries.map((entry) {
                          final index = entry.key;
                          final device = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppCustomTokens.spaceSm,
                            ),
                            child: DeviceListItem(
                              device: device,
                              displayName: deviceDisplayName(device, index),
                              index: index,
                              onOpen: () => onOpenDevice(device),
                              onMenu: () => onMenu(device),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _BottomCharacter(),
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
                    _bottomReserve(context),
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

/// 底部角色插画（order_bottom_character），固定在底栏上方居中偏右。
class _BottomCharacter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: AppCustomTokens.bottomBarHeight +
          bottomInset +
          AppCustomTokens.spaceLg,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: AppCustomTokens.spaceMd),
          child: DecorativeImage(
            ShuiAssets.orderBottomCharacter,
            size: AppCustomTokens.bottomCharacterSize,
            opacity: AppCustomTokens.alphaNearOpaque,
          ),
        ),
      ),
    );
  }
}
