// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used indirectly by UI consumers; this file keeps state/data free of visual constants.

import 'dart:async';

import 'package:flutter/widgets.dart';

enum RuntimeTaskState {
  idle,
  loading,
  success,
  failure,
  loginRequired,
  permissionRequired,
  paymentInProgress,
  unavailable,
}

enum BathSystemPreference { zhuli, shower798 }

enum HomeTaskTarget { hotwater, drinking, washer }

@immutable
class RuntimeActionStatus {
  const RuntimeActionStatus({this.state = RuntimeTaskState.idle, this.message});

  final RuntimeTaskState state;
  final String? message;

  bool get isBusy =>
      state == RuntimeTaskState.loading ||
      state == RuntimeTaskState.paymentInProgress;
}

@immutable
class HomeTaskUi {
  const HomeTaskUi({
    required this.target,
    required this.title,
    required this.extra,
    required this.asset,
  });

  final HomeTaskTarget target;
  final String title;
  final String extra;
  final String asset;
}

@immutable
class ShuiHomeState {
  const ShuiHomeState({
    this.hotwaterStart = const RuntimeActionStatus(
      state: RuntimeTaskState.success,
      message: '热水供应中',
    ),
    this.hotwaterStop = const RuntimeActionStatus(),
    this.waterScan = const RuntimeActionStatus(
      state: RuntimeTaskState.idle,
      message: '扫描饮水机或洗衣机二维码',
    ),
    this.washerScan = const RuntimeActionStatus(),
    this.bathSystemPreference = BathSystemPreference.zhuli,
    this.hotwaterRunning = true,
    this.currentWaterOrderActive = true,
    this.currentWasherOrderActive = true,
    this.localWasherCount = 3,
    this.availableWasherCount = 2,
  });

  final RuntimeActionStatus hotwaterStart;
  final RuntimeActionStatus hotwaterStop;
  final RuntimeActionStatus waterScan;
  final RuntimeActionStatus washerScan;
  final BathSystemPreference bathSystemPreference;
  final bool hotwaterRunning;
  final bool currentWaterOrderActive;
  final bool currentWasherOrderActive;
  final int localWasherCount;
  final int availableWasherCount;

  List<HomeTaskUi> get homeTasks {
    final tasks = <HomeTaskUi>[];
    if (hotwaterRunning) {
      tasks.add(
        const HomeTaskUi(
          target: HomeTaskTarget.hotwater,
          title: '热水使用中',
          extra: '设备 1006445',
          asset: 'shui_reshui.png',
        ),
      );
    }
    if (currentWaterOrderActive) {
      tasks.add(
        const HomeTaskUi(
          target: HomeTaskTarget.drinking,
          title: '饮水订单等待完成',
          extra: '机器按钮决定出水',
          asset: 'shui_jieshui.png',
        ),
      );
    }
    if (currentWasherOrderActive) {
      tasks.add(
        const HomeTaskUi(
          target: HomeTaskTarget.washer,
          title: '洗衣预约中',
          extra: '支付后可自动启动',
          asset: 'shui_yifu.png',
        ),
      );
    }
    return tasks;
  }

  ShuiHomeState copyWith({
    RuntimeActionStatus? hotwaterStart,
    RuntimeActionStatus? hotwaterStop,
    RuntimeActionStatus? waterScan,
    RuntimeActionStatus? washerScan,
    BathSystemPreference? bathSystemPreference,
    bool? hotwaterRunning,
    bool? currentWaterOrderActive,
    bool? currentWasherOrderActive,
    int? localWasherCount,
    int? availableWasherCount,
  }) {
    return ShuiHomeState(
      hotwaterStart: hotwaterStart ?? this.hotwaterStart,
      hotwaterStop: hotwaterStop ?? this.hotwaterStop,
      waterScan: waterScan ?? this.waterScan,
      washerScan: washerScan ?? this.washerScan,
      bathSystemPreference: bathSystemPreference ?? this.bathSystemPreference,
      hotwaterRunning: hotwaterRunning ?? this.hotwaterRunning,
      currentWaterOrderActive:
          currentWaterOrderActive ?? this.currentWaterOrderActive,
      currentWasherOrderActive:
          currentWasherOrderActive ?? this.currentWasherOrderActive,
      localWasherCount: localWasherCount ?? this.localWasherCount,
      availableWasherCount: availableWasherCount ?? this.availableWasherCount,
    );
  }
}

class FakeShuiRuntime extends ChangeNotifier {
  ShuiHomeState _state = const ShuiHomeState();
  Timer? _messageTimer;

  ShuiHomeState get state => _state;

  Future<void> toggleHotwater() async {
    if (_state.hotwaterStart.isBusy || _state.hotwaterStop.isBusy) {
      return;
    }

    if (_state.hotwaterRunning) {
      _state = _state.copyWith(
        hotwaterStop: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在关闭热水',
        ),
      );
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 620));
      _state = _state.copyWith(
        hotwaterRunning: false,
        hotwaterStop: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '热水已关闭',
        ),
        hotwaterStart: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '热水待启动',
        ),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      hotwaterStart: const RuntimeActionStatus(
        state: RuntimeTaskState.loading,
        message: '正在启动热水',
      ),
    );
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 620));
    _state = _state.copyWith(
      hotwaterRunning: true,
      hotwaterStart: const RuntimeActionStatus(
        state: RuntimeTaskState.success,
        message: '热水已启动',
      ),
    );
    notifyListeners();
  }

  Future<void> simulateScan() async {
    _state = _state.copyWith(
      waterScan: const RuntimeActionStatus(
        state: RuntimeTaskState.loading,
        message: '正在识别二维码',
      ),
    );
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 620));
    _state = _state.copyWith(
      currentWaterOrderActive: true,
      waterScan: const RuntimeActionStatus(
        state: RuntimeTaskState.success,
        message: '已识别饮水机，后续模块将接入 ready → create → poll 流程',
      ),
    );
    notifyListeners();
    _clearBannerLater();
  }

  void openWasherSummary() {
    _state = _state.copyWith(
      currentWasherOrderActive: true,
      washerScan: const RuntimeActionStatus(
        state: RuntimeTaskState.success,
        message: '已进入洗衣设备入口；完整下单会在 Washer 模块实现',
      ),
    );
    notifyListeners();
    _clearBannerLater();
  }

  void switchBathSystem() {
    final next = _state.bathSystemPreference == BathSystemPreference.zhuli
        ? BathSystemPreference.shower798
        : BathSystemPreference.zhuli;
    _state = _state.copyWith(bathSystemPreference: next);
    notifyListeners();
  }

  void _clearBannerLater() {
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 4), () {
      _state = _state.copyWith(
        waterScan: const RuntimeActionStatus(
          state: RuntimeTaskState.idle,
          message: '扫描饮水机或洗衣机二维码',
        ),
        washerScan: const RuntimeActionStatus(),
      );
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }
}

class ShuiRuntimeScope extends StatefulWidget {
  const ShuiRuntimeScope({required this.child, super.key});

  final Widget child;

  static FakeShuiRuntime of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShuiRuntimeInherited>();
    assert(scope != null, 'ShuiRuntimeScope is missing from the widget tree.');
    return scope!.runtime;
  }

  @override
  State<ShuiRuntimeScope> createState() => _ShuiRuntimeScopeState();
}

class _ShuiRuntimeScopeState extends State<ShuiRuntimeScope> {
  late final FakeShuiRuntime runtime;

  @override
  void initState() {
    super.initState();
    runtime = FakeShuiRuntime();
  }

  @override
  void dispose() {
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShuiRuntimeInherited(runtime: runtime, child: widget.child);
  }
}

class _ShuiRuntimeInherited extends InheritedNotifier<FakeShuiRuntime> {
  const _ShuiRuntimeInherited({required this.runtime, required super.child})
      : super(notifier: runtime);

  final FakeShuiRuntime runtime;
}
