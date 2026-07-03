// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Hotwater control actions (Module H1; Zhuli part refactored in P4 Z1 to orchestrate IHotwaterAdapter).
// Boundary: Zhuli hot water (start/stop/history) goes through the injected `hotwater` adapter
// (Fake by default, RealZhuliAdapter on device — signed HTTP + BLE). 798 shower (start/stop) stays
// INLINE fake here — it's HTTP not BLE, a separate future adapter. Messages align 1:1 with legacy.

import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../../data/adapters/shower798_adapter.dart';
import '../models/account_session.dart';
import '../models/hotwater_history.dart';
import '../models/local_device.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

mixin HotwaterActions on ShuiRuntimeBase {
  /// 开热水（住理，经 IHotwaterAdapter）：校验登录 + 设备码 → loading → adapter → 供应中 + 写历史。
  /// 对齐 legacy startHotwater。adapter 承载数据 + IO 延迟（fake 620ms / 真实 HTTP↔BLE）。
  Future<void> startHotwater() async {
    if (state.hotwater.start.isBusy) {
      return;
    }
    final zhuli = state.zhuli;
    if (!zhuli.isLoggedIn) {
      _emitStart(RuntimeTaskState.loginRequired, '请先在「我的」登录住理生活');
      return;
    }
    if (zhuli.deviceCode.isEmpty) {
      _emitStart(RuntimeTaskState.loginRequired, '请先绑定热水设备码');
      return;
    }
    _emitStart(RuntimeTaskState.loading, '正在启动热水');
    final HotwaterActionResult result;
    try {
      result = await hotwater.startHotwater(zhuli.deviceCode);
    } on HotwaterException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.zhuli);
        return;
      }
      _emitStart(RuntimeTaskState.failure, e.message);
      return;
    }
    emit(
      state.copyWith(
        hotwater: state.hotwater.copyWith(
          running: true,
          start: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: result.statusText,
          ),
          stop: const RuntimeActionStatus(),
        ),
      ),
    );
  }

  /// 关热水（住理，经 IHotwaterAdapter）。对齐 legacy stopHotwater。
  Future<void> stopHotwater() async {
    if (state.hotwater.stop.isBusy) {
      return;
    }
    _emitStop(RuntimeTaskState.loading, '正在关闭热水');
    final HotwaterActionResult result;
    try {
      result = await hotwater.stopHotwater(state.zhuli.deviceCode);
    } on HotwaterException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.zhuli);
        return;
      }
      _emitStop(RuntimeTaskState.failure, e.message);
      return;
    }
    emit(
      state.copyWith(
        hotwater: state.hotwater.copyWith(
          running: false,
          stop: RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: result.statusText,
          ),
          start: const RuntimeActionStatus(
            state: RuntimeTaskState.idle,
            message: '热水待启动',
          ),
        ),
      ),
    );
  }

  /// 开始洗浴（798，fake）：校验已登录 + 选设备 → loading → 使用中；设备状态联动。
  /// 对齐 legacy startShower798。
  Future<void> startShower798() async {
    if (state.hotwater.start.isBusy) {
      return;
    }
    final deviceId = state.currentShower798DeviceId;
    if (state.shower798Account == null) {
      _emitStart(RuntimeTaskState.loginRequired, '请先登录慧生活798');
      return;
    }
    if (deviceId.isEmpty) {
      _emitStart(RuntimeTaskState.failure, '请先选择 798 设备');
      return;
    }
    _emitStart(RuntimeTaskState.loading, '正在启动 798 洗浴');
    try {
      await shower798.startShower(deviceId);
    } on Shower798Exception catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.shower798);
        return;
      }
      _emitStart(RuntimeTaskState.failure, e.message);
      return;
    }
    emit(
      state.copyWith(
        hotwater: state.hotwater.copyWith(
          running: true,
          start: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '798 洗浴已启动',
          ),
          stop: const RuntimeActionStatus(),
        ),
        shower798Devices: _mapDeviceStatus(deviceId, '使用中'),
        localDevices: _mapLocalStatus(deviceId, '使用中'),
      ),
    );
    // PDEV：798 洗浴改了 localDevices 状态 → 持久化。
    unawaited(devices.saveDevices(state.localDevices));
  }

  /// 结束洗浴（798，经 IShower798Adapter）。对齐 legacy stopShower798。
  Future<void> stopShower798() async {
    if (state.hotwater.stop.isBusy) {
      return;
    }
    final deviceId = state.currentShower798DeviceId;
    if (deviceId.isEmpty) {
      _emitStop(RuntimeTaskState.failure, '请先选择 798 设备');
      return;
    }
    _emitStop(RuntimeTaskState.loading, '正在结束 798 洗浴');
    try {
      await shower798.stopShower(deviceId);
    } on Shower798Exception catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.shower798);
        return;
      }
      _emitStop(RuntimeTaskState.failure, e.message);
      return;
    }
    emit(
      state.copyWith(
        hotwater: state.hotwater.copyWith(
          running: false,
          stop: const RuntimeActionStatus(
            state: RuntimeTaskState.success,
            message: '798 洗浴已结束',
          ),
          start: const RuntimeActionStatus(
            state: RuntimeTaskState.idle,
            message: '洗浴待启动',
          ),
        ),
        shower798Devices: _mapDeviceStatus(deviceId, '空闲'),
        localDevices: _mapLocalStatus(deviceId, '空闲'),
      ),
    );
    // PDEV：798 洗浴改了 localDevices 状态 → 持久化。
    unawaited(devices.saveDevices(state.localDevices));
  }

  /// 加载热水历史（经 IHotwaterAdapter）。对齐 legacy loadHotwaterHistory：每次进详情都拉一次
  /// 真实历史并**替换**（非 append）现有列表——P1-FIX：去掉旧「非空即跳过」早返回，那会让
  /// 曾经落盘的假历史（¥1.20/¥2.40）永久冻结、真实数据永不覆盖。失败保留现有（离线可看）。
  Future<void> loadHotwaterHistory() async {
    emit(
      state.copyWith(
        hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在加载热水历史',
        ),
      ),
    );
    final List<HotwaterHistoryUi> history;
    try {
      history = await hotwater.loadHistory();
    } on HotwaterException catch (e) {
      if (e.authInvalid) {
        await handleAuthInvalidation(AuthService.zhuli);
        return;
      }
      emit(
        state.copyWith(
          hotwaterHistoryStatus: RuntimeActionStatus(
            state: RuntimeTaskState.failure,
            message: e.message,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        hotwaterHistory: history,
        hotwaterHistoryStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '热水历史已加载',
        ),
      ),
    );
    // PHIST：拉取到的真实历史落盘，重启可恢复；下次进详情再拉一次覆盖（不再冻结旧值）。
    _persistHistory();
  }

  /// 持久化当前热水历史（fire-and-forget，对齐 devices_actions._persistDevices 范式）。
  void _persistHistory() {
    unawaited(history.saveHistory(state.hotwater.history));
  }

  void _emitStart(RuntimeTaskState taskState, String message) {
    emit(
      state.copyWith(
        hotwaterStart: RuntimeActionStatus(state: taskState, message: message),
      ),
    );
  }

  void _emitStop(RuntimeTaskState taskState, String message) {
    emit(
      state.copyWith(
        hotwaterStop: RuntimeActionStatus(state: taskState, message: message),
      ),
    );
  }

  List<Shower798DeviceUi> _mapDeviceStatus(String deviceId, String status) {
    return state.shower798Devices
        .map(
          (d) => d.id == deviceId
              ? Shower798DeviceUi(id: d.id, name: d.name, lastStatus: status)
              : d,
        )
        .toList();
  }

  List<LocalDeviceShortcut> _mapLocalStatus(String deviceId, String status) {
    return state.localDevices
        .map(
          (d) => d.deviceType == LocalDeviceType.shower798 && d.id == deviceId
              ? d.copyWith(lastStatus: status)
              : d,
        )
        .toList();
  }
}
