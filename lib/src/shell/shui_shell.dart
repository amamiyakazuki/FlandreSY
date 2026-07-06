// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Routing orchestration only; visual chrome lives in shui_shell_chrome.dart (token-compliant).

import 'package:flutter/material.dart';

import '../devices/device_dialogs.dart';
import '../devices/devices_screen.dart';
import '../devices/drinking_water_screen.dart';
import '../home/home_screen.dart';
import '../more/more_options_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/account_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/account_session.dart';
import '../runtime/models/local_device.dart';
import '../runtime/scan_routing.dart';
import '../theme/shui_motion.dart';
import '../washer/washer_order_screen.dart';
import '../widgets/qr_scanner_screen.dart';
import '../widgets/shui_components.dart';
import 'shui_route.dart';
import 'shui_shell_chrome.dart';

enum MainTab {
  home('功能', 'home'),
  orders('订单', 'orders'),
  devices('设备', 'washer'),
  profile('我的', 'profile');

  const MainTab(this.label, this.iconName);

  final String label;
  final String iconName;
}

class ShuiShell extends StatefulWidget {
  const ShuiShell({super.key});

  @override
  State<ShuiShell> createState() => _ShuiShellState();
}

class _ShuiShellState extends State<ShuiShell> {
  /// 当前路由（替代原先的纯 tab 切换，支持 push 子页面 + 返回栈）。
  ShuiRoute route = const TabRoute(MainTab.home);

  bool openingVisible = true;
  bool permissionVisible = true;

  // Devices 模块的对话框/弹层状态（叠加在路由之上，由 PopScope 优先消费返回）。
  bool showAddDevice = false;
  bool showPresetPicker = false;
  LocalDeviceShortcut? menuDevice;
  LocalDeviceShortcut? editingDevice;

  /// 标记当前饮水订单是否已创建过：用于「创建后被清空」=完成 的判定，
  /// 避免进入页面初始 null 被误判为完成。
  bool _drinkingOrderWasActive = false;

  bool get _hasOverlay =>
      showAddDevice ||
      showPresetPicker ||
      menuDevice != null ||
      editingDevice != null;

  bool get _canPop => !_hasOverlay && route is TabRoute;

  MainTab get _selectedTab => route.parentTab;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(ShuiMotion.opening, () {
      if (mounted) {
        setState(() => openingVisible = false);
      }
    });
  }

  void _selectTab(MainTab tab) {
    setState(() {
      _dismissOverlays();
      route = TabRoute(tab);
    });
  }

  void _dismissOverlays() {
    showAddDevice = false;
    showPresetPicker = false;
    menuDevice = null;
    editingDevice = null;
  }

  /// 返回处理优先级：先关弹层 → 再关 popup → 再退子页面回 Tab。
  void _handlePop() {
    final runtime = ShuiRuntimeScope.of(context);
    setState(() {
      if (editingDevice != null) {
        editingDevice = null;
      } else if (showPresetPicker) {
        showPresetPicker = false;
      } else if (showAddDevice) {
        showAddDevice = false;
      } else if (menuDevice != null) {
        menuDevice = null;
      } else if (route is WasherOrderRoute) {
        // 退出洗衣下单页时清理瞬态（program/order/payment）。
        runtime.resetWasherTransient();
        route = TabRoute(route.parentTab);
      } else if (route is! TabRoute) {
        route = TabRoute(route.parentTab);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ShuiRuntimeScope.of(context);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePop();
        }
      },
      child: AnimatedBuilder(
        animation: runtime,
        builder: (context, _) {
          _maybeReturnAfterDrinkingComplete(runtime);
          return AdaptivePhoneContainer(
            // Shell 的根是裸 Stack（无 Scaffold/Material 祖先），WidgetsApp 的 fallback
            // DefaultTextStyle 带黄色双下划线 decoration（Flutter 用它提示「不在 Material 内」）。
            // 底栏 tab、设备对话框等 Stack 兄弟的文本用 copyWith(color:) 只覆盖颜色，会继承该
            // 下划线 → 真机出现黄色双下划线。此处 merge 一个 decoration:none 统一消除；
            // 它是纯 InheritedWidget（无合成层），golden 下文本本就无下划线故为像素级 no-op。
            child: DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: ShuiMotion.route,
                    switchInCurve: ShuiMotion.easeOut,
                    switchOutCurve: ShuiMotion.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _routeBody(runtime),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: WavyBottomBar(
                      selectedTab: _selectedTab,
                      onTabSelected: _selectTab,
                    ),
                  ),
                  ..._overlays(runtime),
                  AnimatedSwitcher(
                    duration: ShuiMotion.normal,
                    child: openingVisible
                        ? const OpeningMotionOverlay()
                        : const SizedBox.shrink(),
                  ),
                  AnimatedSwitcher(
                    duration: ShuiMotion.normal,
                    child: permissionVisible && !openingVisible
                        ? FirstLaunchPermissionDialog(
                            onConfirm: () =>
                                setState(() => permissionVisible = false),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _routeBody(FakeShuiRuntime runtime) {
    final body = switch (route) {
      TabRoute(:final tab) => _tabBody(runtime, tab),
      EmptyDevicesRoute() => EmptyDevicesView(
          onBack: () => _selectTab(MainTab.devices),
          onAdd: () => setState(() => showAddDevice = true),
        ),
      DrinkingWaterRoute(:final cd) => DrinkingWaterScreen(
          cd: cd,
          state: runtime.state,
          onBack: () => _leaveDrinkingWater(runtime),
          onRefresh: runtime.refreshCurrentDrinkingWaterOrder,
        ),
      AccountDetailRoute(:final kind) => AccountDetailScreen(
          kind: kind,
          state: runtime.state,
          nowMillis: runtime.clock.nowMillis(),
          onBack: () => _selectTab(MainTab.profile),
          onLoginZhuli: runtime.loginZhuli,
          onBindDeviceCode: runtime.bindHotwaterDeviceCode,
          onCheckZhuli: runtime.checkZhuliStatus,
          onRequestUjingCaptcha: runtime.requestUjingCaptcha,
          onLoginUjing: runtime.loginUjing,
          onCheckUjing: runtime.checkUjingStatus,
          onRequestShower798Captcha: runtime.requestShower798Captcha,
          onSendShower798Sms: runtime.sendShower798SmsCode,
          onLoginShower798: runtime.loginShower798,
          onAddShower798Device: runtime.addShower798Device,
          onRefreshShower798Devices: runtime.refreshShower798Devices,
          onSelectShower798Device: runtime.selectShower798Device,
        ),
      WasherOrderRoute() => WasherOrderScreen(
          state: runtime.state,
          onBack: () => _leaveWasherOrder(runtime),
          onCreateOrder: (model, temp, detergent, disinfectant) =>
              runtime.createWasherOrder(
            washModelId: model,
            temperatureId: temp,
            detergentGearId: detergent,
            disinfectantGearId: disinfectant,
          ),
          onPay: runtime.payCurrentWasherOrderWithAlipay,
          onStart: runtime.startCurrentWasherOrder,
          onStop: runtime.stopCurrentWasherOrder,
          onCancel: runtime.cancelCurrentWasherOrder,
        ),
      MoreOptionsRoute() => MoreOptionsScreen(
          onBack: () => _selectTab(MainTab.profile),
          onImportDevices: runtime.refreshLocalDevices,
          useSimulatedBackend: runtime.state.useSimulatedBackend,
          onToggleSimulatedBackend: runtime.setUseSimulatedBackend,
        ),
    };
    return KeyedSubtree(key: ValueKey(_routeKey()), child: body);
  }

  String _routeKey() {
    return switch (route) {
      TabRoute(:final tab) => 'tab-${tab.name}',
      EmptyDevicesRoute() => 'empty-devices',
      DrinkingWaterRoute(:final cd) => 'drinking-$cd',
      AccountDetailRoute(:final kind) => 'account-${kind.name}',
      WasherOrderRoute(:final qr) => 'washer-$qr',
      MoreOptionsRoute() => 'more-options',
    };
  }

  Widget _tabBody(FakeShuiRuntime runtime, MainTab tab) {
    return switch (tab) {
      MainTab.home => HomeScreen(
          state: runtime.state,
          onOpenProfile: () => _selectTab(MainTab.profile),
          onOpenDevices: () => _selectTab(MainTab.devices),
          onStartHotwater: () => _startHotwater(runtime),
          onStopHotwater: () => _stopHotwater(runtime),
          onScan: () => _scanFromHome(runtime),
          onWasherSummary: runtime.openWasherSummary,
          onSwitchBathSystem: runtime.switchBathSystem,
        ),
      MainTab.orders => OrdersScreen(
          state: runtime.state,
          clock: runtime.clock,
          onBack: () => _selectTab(MainTab.home),
          onOpenWasherOrder: () {
            final order = runtime.state.washer.currentOrder;
            if (order != null) {
              setState(() => route = WasherOrderRoute(order.deviceNo));
            }
          },
          onOpenDrinking: () {
            final cd = runtime.state.currentWaterOrder?.deviceNo ?? '';
            setState(() => route = DrinkingWaterRoute(cd));
          },
          onPollWasher: runtime.refreshCurrentWasherOrder,
          onLoadHotwaterHistory: runtime.loadHotwaterHistory,
        ),
      MainTab.devices => runtime.state.visibleDevices.isEmpty
          ? EmptyDevicesView(
              onBack: () => _selectTab(MainTab.home),
              onAdd: () => setState(() => showAddDevice = true),
            )
          : DevicesScreen(
              state: runtime.state,
              onAdd: () => setState(() => showAddDevice = true),
              onBack: () => _selectTab(MainTab.home),
              onRefresh: runtime.refreshLocalDevices,
              onOpenDevice: (device) => _openDevice(runtime, device),
              onMenu: (device) => setState(() => menuDevice = device),
            ),
      MainTab.profile => ProfileScreen(
          state: runtime.state,
          onSwitchBathSystem: runtime.switchBathSystem,
          onOpenBathAccount: () {
            // 浴室系统卡：住理 / 798 分别进各自登录详情（对齐 legacy onOpen 分发）。
            if (runtime.state.bathSystemPreference ==
                BathSystemPreference.shower798) {
              setState(
                () => route = const AccountDetailRoute(AccountKind.shower798),
              );
            } else {
              setState(() => route = const AccountDetailRoute(AccountKind.zhuli));
            }
          },
          onOpenUjing: () =>
              setState(() => route = const AccountDetailRoute(AccountKind.ujing)),
          onOpenMore: () => setState(() => route = const MoreOptionsRoute()),
        ),
    };
  }

  void _openDevice(FakeShuiRuntime runtime, LocalDeviceShortcut device) {
    if (device.deviceType == LocalDeviceType.drinkingWater) {
      final cd = device.cd ?? '';
      setState(() => route = DrinkingWaterRoute(cd));
      // 进入饮水页自动 ready + 创建接水订单（对齐 legacy 扫码后一步式流程）。
      runtime.scanDrinkingWaterAndCreateOrder(cd);
      return;
    }
    // 洗衣机（W1）：进入下单页并 fake 扫码识别 program。
    final qr = device.qrUrl ?? '';
    setState(() => route = WasherOrderRoute(qr));
    runtime.scanWasher(qr);
  }

  /// 离开洗衣下单页：清理 washer 瞬态，回到 Devices tab。
  void _leaveWasherOrder(FakeShuiRuntime runtime) {
    runtime.resetWasherTransient();
    _selectTab(MainTab.devices);
  }

  /// 首页扫码卡 → 打开真实相机（RSCAN）→ 得 qr → classifyScanRouting 分类 →
  /// 洗衣机：自动加到设备页（去重+持久化）后进下单页 + scanWasher；
  /// 饮水机回首页 + 一步式接水（一次性，不落设备）；无法识别 → SnackBar 提示。
  /// 对齐 legacy ShuiScreens.kt scannerLauncher 分发。相机层由用户真机验证。
  Future<void> _scanFromHome(FakeShuiRuntime runtime) async {
    final qr = await _openScanner();
    if (qr == null || !mounted) {
      return;
    }
    final routing = classifyScanRouting(qr);
    switch (routing) {
      case ScanRoutingWasher():
        // 洗衣机需反复使用 → 首页扫码也自动加到设备页（addScannedDeviceFromQr
        // 内部按 qrUrl 去重 + 持久化，重复扫不会重复加），再进下单页。
        runtime.addScannedDeviceFromQr(qr);
        setState(() => route = WasherOrderRoute(qr));
        runtime.scanWasher(qr);
      case ScanRoutingDrinkingWater(:final cd):
        setState(() => route = const TabRoute(MainTab.home));
        runtime.scanDrinkingWaterAndCreateOrder(cd);
      case ScanRoutingUnknown(:final reason):
        _showScanMessage(reason);
    }
  }

  /// 设备页「+」→「开始扫码」→ 打开真实相机（RSCAN）→ 得 qr →
  /// runtime.addScannedDeviceFromQr（分类落洗衣/饮水快捷入口，去重 + 持久化）。
  Future<void> _scanToAddDevice(FakeShuiRuntime runtime) async {
    final qr = await _openScanner();
    if (qr == null || !mounted) {
      return;
    }
    runtime.addScannedDeviceFromQr(qr);
  }

  /// 打开全屏扫码页，返回识别到的 qr 字符串（取消返回 null）。
  Future<String?> _openScanner() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const QrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showScanMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 按浴室偏好路由热水启动：798（已登录+选设备）走洗浴，否则走住理热水。
  bool _use798(FakeShuiRuntime runtime) {
    final s = runtime.state;
    return s.bathSystemPreference == BathSystemPreference.shower798 &&
        s.shower798Account != null &&
        s.currentShower798DeviceId.isNotEmpty;
  }

  void _startHotwater(FakeShuiRuntime runtime) {
    if (_use798(runtime)) {
      runtime.startShower798();
    } else {
      runtime.startHotwater();
    }
  }

  void _stopHotwater(FakeShuiRuntime runtime) {
    if (_use798(runtime)) {
      runtime.stopShower798();
    } else {
      runtime.stopHotwater();
    }
  }

  /// 离开饮水页：清理 ready/banner，回到 Devices tab。
  void _leaveDrinkingWater(FakeShuiRuntime runtime) {
    _drinkingOrderWasActive = false;
    runtime.resetDrinkingWaterTransient();
    _selectTab(MainTab.devices);
  }

  /// 饮水完成自动回 Home（对齐 legacy onCompleted）：
  /// 当前在饮水页、订单曾创建、现已被清空且消息含「完成」→ 下一帧回 Home。
  void _maybeReturnAfterDrinkingComplete(FakeShuiRuntime runtime) {
    if (route is! DrinkingWaterRoute) {
      return;
    }
    final s = runtime.state;
    if (s.currentWaterOrder != null) {
      _drinkingOrderWasActive = true;
      return;
    }
    final completed = _drinkingOrderWasActive &&
        s.waterOrder.state == RuntimeTaskState.success &&
        (s.waterOrder.message?.contains('完成') ?? false);
    if (completed) {
      _drinkingOrderWasActive = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route is DrinkingWaterRoute) {
          setState(() => route = const TabRoute(MainTab.home));
        }
      });
    }
  }

  List<Widget> _overlays(FakeShuiRuntime runtime) {
    return [
      if (showAddDevice && !showPresetPicker)
        AddDeviceDialog(
          onDismiss: () => setState(() => showAddDevice = false),
          onScan: () {
            setState(() => showAddDevice = false);
            _scanToAddDevice(runtime);
          },
          onPreset: () => setState(() => showPresetPicker = true),
        ),
      if (showPresetPicker)
        PresetDeviceDialog(
          onDismiss: () => setState(() => showPresetPicker = false),
          onSelect: (preset) {
            runtime.addPresetWasherDevice(preset.name, preset.qrCode);
            setState(() {
              showPresetPicker = false;
              showAddDevice = false;
            });
          },
        ),
      if (menuDevice != null && editingDevice == null)
        DeviceActionPopup(
          onDismiss: () => setState(() => menuDevice = null),
          onEdit: () => setState(() {
            editingDevice = menuDevice;
            menuDevice = null;
          }),
          onDelete: () {
            runtime.deleteLocalDevice(menuDevice!.id);
            setState(() => menuDevice = null);
          },
        ),
      if (editingDevice != null)
        EditDeviceNameDialog(
          initialName: editingDevice!.customName,
          onDismiss: () => setState(() => editingDevice = null),
          onSave: (name) {
            runtime.renameLocalDevice(editingDevice!.id, name);
            setState(() => editingDevice = null);
          },
        ),
    ];
  }
}
