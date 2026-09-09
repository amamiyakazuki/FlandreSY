// Routing orchestration only; visual chrome lives in shui_shell_chrome.dart (token-compliant).

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/local_device_repository.dart';
import '../devices/device_dialogs.dart';
import '../data/permission_service.dart';
import '../devices/devices_screen.dart';
import '../devices/drinking_water_screen.dart';
import '../home/home_screen.dart';
import '../hotwater/hotwater_detail_screen.dart';
import '../more/more_options_screen.dart';
import '../more/log_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/account_detail_screen.dart';
import '../profile/account_hub_screen.dart';
import '../profile/profile_screen.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/local_device.dart';
import '../runtime/scan_routing.dart';
import '../theme/shui_motion.dart';
import '../washer/washer_order_screen.dart';
import '../widgets/qr_scanner_screen.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_overlay_host.dart';
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

class _ShuiDetailPage extends Page<void> {
  const _ShuiDetailPage(
      {required this.child, required this.reduced, required super.key});

  final Widget child;
  final bool reduced;

  @override
  Route<void> createRoute(BuildContext context) => _ShuiDetailRoute(this);
}

class _ShuiDetailRoute extends CupertinoPageRoute<void> {
  _ShuiDetailRoute(_ShuiDetailPage page)
      : super(settings: page, builder: (_) => page.child);

  _ShuiDetailPage get page => settings as _ShuiDetailPage;

  @override
  Duration get transitionDuration =>
      page.reduced ? Duration.zero : ShuiMotion.route;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildContent(BuildContext context) => page.child;
}

class ShuiShell extends StatefulWidget {
  const ShuiShell({super.key});

  @override
  State<ShuiShell> createState() => _ShuiShellState();
}

class _ShuiShellState extends State<ShuiShell> with WidgetsBindingObserver {
  /// 当前路由（替代原先的纯 tab 切换，支持 push 子页面 + 返回栈）。
  MainTab _mainTab = MainTab.home;
  final List<ShuiRoute> _details = [];
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ShuiRoute get route => _details.isEmpty ? TabRoute(_mainTab) : _details.last;
  int _routeDirection = 1;
  bool _scannerOpen = false;
  bool _foreground = true;

  bool openingVisible = true;
  bool permissionVisible = true;
  final ShuiPermissionService _permissionService =
      const ShuiPermissionService();
  ShuiPermissionState? _permissionState;

  // Devices 模块的对话框/弹层状态（叠加在路由之上，由 PopScope 优先消费返回）。
  bool showAddDevice = false;
  bool showPresetPicker = false;
  LocalDeviceShortcut? menuDevice;
  LocalDeviceShortcut? editingDevice;

  bool get _hasOverlay =>
      showAddDevice ||
      showPresetPicker ||
      menuDevice != null ||
      editingDevice != null;

  bool get _canPop => !_hasOverlay && route is TabRoute;

  MainTab get _selectedTab => route.parentTab;

  bool get _showBottomBar => switch (route) {
        DrinkingWaterRoute() || WasherOrderRoute() => false,
        _ => true,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(ShuiMotion.duration(context, ShuiMotion.opening),
          () {
        if (mounted) setState(() => openingVisible = false);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final permissions = await _permissionService.check();
    if (mounted) setState(() => _permissionState = permissions);
  }

  Future<void> _requestPermissions() async {
    setState(() {
      permissionVisible = false;
    });
    ShuiRuntimeScope.of(context).markPermissionIntroSeen();
    final permissions = await _permissionService.requestAll();
    if (mounted) setState(() => _permissionState = permissions);
  }

  void _selectTab(MainTab tab) {
    final currentIndex = _selectedTab.index;
    _cleanUpRoute(route);
    setState(() {
      _dismissOverlays();
      _routeDirection = tab.index >= currentIndex ? 1 : -1;
      _mainTab = tab;
      _details.clear();
    });
  }

  void _setRoute(ShuiRoute next, {bool returning = false}) {
    if (_routeKey(next) == _routeKey(route)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _dismissOverlays();
      _routeDirection = returning ? -1 : 1;
      if (next is TabRoute) {
        _mainTab = next.tab;
        _details.clear();
      } else if (returning && _details.length > 1) {
        _details.removeLast();
      } else {
        _details.add(next);
      }
    });
  }

  void _cleanUpRoute(ShuiRoute leaving) {
    final runtime = ShuiRuntimeScope.of(context);
    if (leaving is WasherOrderRoute) runtime.resetWasherTransient();
    if (leaving is DrinkingWaterRoute) runtime.resetDrinkingWaterTransient();
  }

  void _dismissOverlays() {
    showAddDevice = false;
    showPresetPicker = false;
    menuDevice = null;
    editingDevice = null;
  }

  /// 返回处理优先级：先关弹层 → 再关 popup → 再退子页面回 Tab。
  void _handlePop() {
    setState(() {
      if (editingDevice != null) {
        editingDevice = null;
      } else if (showPresetPicker) {
        showPresetPicker = false;
      } else if (showAddDevice) {
        showAddDevice = false;
      } else if (menuDevice != null) {
        menuDevice = null;
      } else if (_details.isNotEmpty) {
        _cleanUpRoute(route);
        _routeDirection = -1;
        _details.removeLast();
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
          if (!_hasOverlay && _details.isNotEmpty) {
            _navigatorKey.currentState?.maybePop();
          } else {
            _handlePop();
          }
        }
      },
      child: AnimatedBuilder(
        animation: runtime,
        builder: (context, _) {
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
                  Navigator(
                    key: _navigatorKey,
                    pages: [
                      MaterialPage<void>(
                        key: const ValueKey('tabs'),
                        child: Stack(
                          children: [
                            for (final tab in MainTab.values)
                              Offstage(
                                offstage: tab != _mainTab,
                                child: TickerMode(
                                  enabled: tab == _mainTab && _details.isEmpty,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(end: tab == _mainTab ? 1 : 0),
                                    duration: ShuiMotion.duration(
                                        context, ShuiMotion.route),
                                    curve: ShuiMotion.easeOut,
                                    builder: (context, value, child) =>
                                        FractionalTranslation(
                                      translation: Offset(
                                          (1 - value) *
                                              0.045 *
                                              _routeDirection *
                                              (Directionality.of(context) ==
                                                      TextDirection.rtl
                                                  ? -1
                                                  : 1),
                                          0),
                                      child:
                                          Opacity(opacity: value, child: child),
                                    ),
                                    child: _tabBody(runtime, tab),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final destination in _details)
                        _ShuiDetailPage(
                          key: ValueKey(_routeKey(destination)),
                          child: _routeBody(runtime, destination),
                          reduced: ShuiMotion.reduced(context),
                        ),
                    ],
                    onDidRemovePage: (page) {
                      final index = _details.indexWhere(
                          (entry) => ValueKey(_routeKey(entry)) == page.key);
                      if (index < 0) return;
                      _cleanUpRoute(_details[index]);
                      setState(
                          () => _details.removeRange(index, _details.length));
                    },
                  ),
                  AnimatedSwitcher(
                    duration: ShuiMotion.duration(context, ShuiMotion.route),
                    switchInCurve: ShuiMotion.easeOut,
                    switchOutCurve: ShuiMotion.easeIn,
                    child: _showBottomBar
                        ? Align(
                            key: const ValueKey('bottom-bar-visible'),
                            alignment: Alignment.bottomCenter,
                            child: WavyBottomBar(
                              selectedTab: _selectedTab,
                              onTabSelected: _selectTab,
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('bottom-bar-hidden'),
                          ),
                  ),
                  ShuiOverlayHost(
                    child: !_hasOverlay
                        ? null
                        : KeyedSubtree(
                            key: ValueKey(_overlayKey()),
                            child: Stack(children: _overlays(runtime)),
                          ),
                  ),
                  AnimatedSwitcher(
                    duration: ShuiMotion.duration(context, ShuiMotion.normal),
                    child: openingVisible
                        ? const OpeningMotionOverlay()
                        : const SizedBox.shrink(),
                  ),
                  AnimatedSwitcher(
                    duration: ShuiMotion.duration(context, ShuiMotion.normal),
                    child: permissionVisible &&
                            !openingVisible &&
                            !runtime.state.permissionIntroSeen
                        ? FirstLaunchPermissionDialog(
                            permissionState: _permissionState,
                            onConfirm: _requestPermissions,
                            onOpenSettings: () {
                              _permissionService.openSettings();
                            },
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

  String _overlayKey() {
    if (editingDevice != null) return 'edit-device';
    if (menuDevice != null) return 'device-menu-${menuDevice!.id}';
    if (showPresetPicker) return 'preset-picker';
    if (showAddDevice) return 'add-device';
    return 'no-overlay';
  }

  Widget _routeBody(FakeShuiRuntime runtime, ShuiRoute route) {
    final body = switch (route) {
      TabRoute(:final tab) => _tabBody(runtime, tab),
      EmptyDevicesRoute() => EmptyDevicesView(
          onBack: _handlePop,
          onAdd: () => setState(() => showAddDevice = true),
        ),
      DrinkingWaterRoute(:final cd) => DrinkingWaterScreen(
          cd: cd,
          state: runtime.state,
          onBack: () => _leaveDrinkingWater(runtime),
          onReturnHome: () => _selectTab(MainTab.home),
          onRefresh: runtime.refreshCurrentDrinkingWaterOrder,
        ),
      AccountHubRoute() => AccountHubScreen(
          state: runtime.state,
          onBack: _handlePop,
          onSelect: (kind) {
            _setRoute(AccountDetailRoute(kind));
          },
        ),
      AccountDetailRoute(:final kind) => AccountDetailScreen(
          kind: kind,
          state: runtime.state,
          nowMillis: runtime.clock.nowMillis(),
          onBack: _handlePop,
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
          onSetDefaultSystem: (system) => runtime.setBathSystem(system),
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
      HotwaterDetailRoute() => HotwaterDetailScreen(
          state: runtime.state,
          onBack: _handlePop,
          onStart: () => _startHotwater(runtime),
          onStop: () => _stopHotwater(runtime),
        ),
      MoreOptionsRoute() => MoreOptionsScreen(
          onBack: _handlePop,
          onImportDevices: () => _importDevices(runtime),
          onExportDevices: () => _exportDevices(runtime),
          onOpenLogs: () => _setRoute(const DiagnosticLogRoute()),
          appVersion: runtime.appVersion,
          useSimulatedBackend: runtime.state.useSimulatedBackend,
          onToggleSimulatedBackend: runtime.setUseSimulatedBackend,
        ),
      DiagnosticLogRoute() => LogScreen(
          log: runtime.diagnosticLog,
          onBack: _handlePop,
        ),
    };
    return KeyedSubtree(key: ValueKey(_routeKey(route)), child: body);
  }

  String _routeKey(ShuiRoute route) {
    return switch (route) {
      TabRoute(:final tab) => 'tab-${tab.name}',
      EmptyDevicesRoute() => 'empty-devices',
      DrinkingWaterRoute(:final cd) => 'drinking-$cd',
      AccountHubRoute() => 'account-hub',
      AccountDetailRoute(:final kind) => 'account-${kind.name}',
      WasherOrderRoute(:final qr) => 'washer-$qr',
      HotwaterDetailRoute() => 'hotwater-detail',
      MoreOptionsRoute() => 'more-options',
      DiagnosticLogRoute() => 'diagnostic-log',
    };
  }

  Future<void> _exportDevices(FakeShuiRuntime runtime) async {
    final json = LocalDeviceCodec.encode(runtime.state.localDevices);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) _showScanMessage('设备列表已复制到剪贴板');
  }

  Future<void> _importDevices(FakeShuiRuntime runtime) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final ok = await runtime.importLocalDevicesFromJson(data?.text ?? '');
    if (mounted) {
      _showScanMessage(ok ? '设备列表已从剪贴板导入' : '剪贴板不是有效设备列表 JSON');
    }
  }

  Widget _tabBody(FakeShuiRuntime runtime, MainTab tab) {
    return switch (tab) {
      MainTab.home => HomeScreen(
          state: runtime.state,
          onOpenProfile: () => _selectTab(MainTab.profile),
          onOpenDevices: () => _selectTab(MainTab.devices),
          onStartHotwater: () => _startHotwater(runtime),
          onStopHotwater: () => _stopHotwater(runtime),
          onOpenHotwaterDetail: () {
            runtime.loadHotwaterHistory();
            _setRoute(const HotwaterDetailRoute());
          },
          onScan: () => _scanFromHome(runtime),
          onWasherSummary: runtime.openWasherSummary,
          onSwitchBathSystem: () => _setRoute(const AccountHubRoute()),
        ),
      MainTab.orders => OrdersScreen(
          active: _foreground && _mainTab == MainTab.orders && _details.isEmpty,
          state: runtime.state,
          clock: runtime.clock,
          onBack: () => _selectTab(MainTab.home),
          onOpenWasherOrder: () {
            final order = runtime.state.washer.currentOrder;
            if (order != null) {
              _setRoute(WasherOrderRoute(order.deviceNo));
            }
          },
          onOpenDrinking: () {
            final cd = runtime.state.currentWaterOrder?.deviceNo ?? '';
            _setRoute(DrinkingWaterRoute(cd));
          },
          onPollWasher: runtime.refreshCurrentWasherOrder,
        ),
      MainTab.devices => DevicesScreen(
          state: runtime.state,
          onAdd: () => setState(() => showAddDevice = true),
          onBack: () => _selectTab(MainTab.home),
          onRefresh: runtime.refreshLocalDevices,
          onOpenDevice: (device) => _openDevice(runtime, device),
          onMenu: (device) => setState(() => menuDevice = device),
        ),
      MainTab.profile => ProfileScreen(
          state: runtime.state,
          onOpenAccountHub: () => _setRoute(const AccountHubRoute()),
          onOpenMore: () => _setRoute(const MoreOptionsRoute()),
        ),
    };
  }

  void _openDevice(FakeShuiRuntime runtime, LocalDeviceShortcut device) {
    if (device.deviceType == LocalDeviceType.drinkingWater) {
      final cd = device.cd ?? '';
      _setRoute(DrinkingWaterRoute(cd));
      // 进入饮水页自动 ready + 创建接水订单（对齐 legacy 扫码后一步式流程）。
      runtime.scanDrinkingWaterAndCreateOrder(cd);
      return;
    }
    // 洗衣机（W1）：进入下单页并 fake 扫码识别 program。
    final qr = device.qrUrl ?? '';
    _setRoute(WasherOrderRoute(qr));
    runtime.scanWasher(qr);
  }

  /// 离开洗衣下单页：清理 washer 瞬态，回到 Devices tab。
  void _leaveWasherOrder(FakeShuiRuntime runtime) {
    _handlePop();
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
        _setRoute(WasherOrderRoute(qr));
        runtime.scanWasher(qr);
      case ScanRoutingDrinkingWater(:final cd):
        _setRoute(DrinkingWaterRoute(cd));
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
  Future<String?> _openScanner() async {
    if (_scannerOpen) return null;
    _scannerOpen = true;
    try {
      return await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const QrScannerScreen(),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _scannerOpen = false;
    }
  }

  void _showScanMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 按浴室偏好路由热水启动：798（已登录+选设备）走洗浴，否则走住理热水。
  bool _use798(FakeShuiRuntime runtime) {
    final s = runtime.state;
    return s.hotwaterControlSystem == BathSystemPreference.shower798;
  }

  void _startHotwater(FakeShuiRuntime runtime) {
    if (runtime.state.hotwaterControlSystem == BathSystemPreference.none) {
      return;
    }
    if (_use798(runtime)) {
      runtime.startShower798();
    } else {
      runtime.startHotwater();
    }
  }

  void _stopHotwater(FakeShuiRuntime runtime) {
    runtime.stopActiveHotwater();
  }

  /// 离开饮水页：清理 ready/banner，回到 Devices tab。
  void _leaveDrinkingWater(FakeShuiRuntime runtime) {
    _handlePop();
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
