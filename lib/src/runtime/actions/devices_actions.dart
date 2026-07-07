// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Devices tab actions (Module B1). Mixin on ShuiRuntimeBase; behavior unchanged by the runtime split.

import 'dart:async';

import '../../data/adapters/ujing_adapter.dart';
import '../../data/local_device_repository.dart';
import '../live_clock.dart';
import '../models/local_device.dart';
import '../runtime_status.dart';
import '../scan_routing.dart';
import '../shui_runtime_base.dart';

mixin DevicesActions on ShuiRuntimeBase {
  /// 添加海七预设洗衣机。重复 qrUrl 不重复添加（按 qrUrl 去重）。
  void addPresetWasherDevice(String name, String qrCode) {
    final exists = state.localDevices.any((d) => d.qrUrl == qrCode);
    if (exists) {
      _emitDevicesNotice('该预设设备已在列表中', RuntimeTaskState.unavailable);
      return;
    }
    deviceSeq += 1;
    final device = LocalDeviceShortcut(
      id: 'preset-$deviceSeq',
      customName: name,
      deviceType: LocalDeviceType.washer,
      qrUrl: qrCode,
      deviceNo: _uuidTail(qrCode),
      storeName: '海七宿舍',
      // P1-FIX：不再硬编码假「可下单」。初始状态未知（null → UI 显「未知」），
      // 点刷新后按 qrUrl 查真实状态回填（见 refreshLocalDevices）。
      sortOrder: deviceSeq,
    );
    emit(state.copyWith(localDevices: [...state.localDevices, device]));
    _persistDevices();
    _emitDevicesNotice('已添加：$name', RuntimeTaskState.success);
  }

  /// 扫码添加设备（RSCAN）：真实相机扫到的 qr 经 [classifyScanRouting] 分类，
  /// 洗衣机 → 落 washer 快捷入口（qrUrl=真实 qr）；饮水机 → 落 drinkingWater（cd=真实 cd）；
  /// 无法识别 → 提示 reason 不落设备。按 qrUrl/cd 去重（对齐预设去重）。
  /// 取代旧 fake `addScannedWasherDevice`（不再造假洗衣机）。
  void addScannedDeviceFromQr(String qrCode) {
    final routing = classifyScanRouting(qrCode);
    switch (routing) {
      case ScanRoutingWasher():
        final qr = qrCode.trim();
        if (state.localDevices.any((d) => d.qrUrl == qr)) {
          _emitDevicesNotice('该设备已在列表中', RuntimeTaskState.unavailable);
          return;
        }
        deviceSeq += 1;
        final device = LocalDeviceShortcut(
          id: 'scanned-$deviceSeq',
          customName: '洗衣机-${_uuidTail(qr)}',
          deviceType: LocalDeviceType.washer,
          qrUrl: qr,
          deviceNo: _uuidTail(qr),
          storeName: '扫码添加',
          // P1-FIX：初始状态未知（null），点刷新后按 qrUrl 查真实状态回填。
          sortOrder: deviceSeq,
        );
        emit(state.copyWith(localDevices: [...state.localDevices, device]));
        _persistDevices();
        _emitDevicesNotice(
            '已通过扫码添加：${device.customName}', RuntimeTaskState.success);
      case ScanRoutingDrinkingWater(:final cd):
        if (state.localDevices.any((d) => d.cd == cd)) {
          _emitDevicesNotice('该饮水机已在列表中', RuntimeTaskState.unavailable);
          return;
        }
        deviceSeq += 1;
        final device = LocalDeviceShortcut(
          id: 'scanned-$deviceSeq',
          customName: '饮水机-$cd',
          deviceType: LocalDeviceType.drinkingWater,
          cd: cd,
          deviceNo: cd,
          storeName: '扫码添加',
          sortOrder: deviceSeq,
        );
        emit(state.copyWith(localDevices: [...state.localDevices, device]));
        _persistDevices();
        _emitDevicesNotice(
            '已通过扫码添加：${device.customName}', RuntimeTaskState.success);
      case ScanRoutingUnknown(:final reason):
        _emitDevicesNotice(reason, RuntimeTaskState.failure);
    }
  }

  /// 重命名本地设备。
  void renameLocalDevice(String id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final updated = state.localDevices
        .map((d) => d.id == id ? d.copyWith(customName: trimmed) : d)
        .toList();
    emit(state.copyWith(localDevices: updated));
    _persistDevices();
    _emitDevicesNotice('已重命名为：$trimmed', RuntimeTaskState.success);
  }

  /// 删除本地设备。
  void deleteLocalDevice(String id) {
    final removed = state.localDevices.firstWhere(
      (d) => d.id == id,
      orElse: () => const LocalDeviceShortcut(
        id: '',
        customName: '',
        deviceType: LocalDeviceType.unknown,
      ),
    );
    final updated = state.localDevices.where((d) => d.id != id).toList();
    emit(state.copyWith(localDevices: updated));
    _persistDevices();
    _emitDevicesNotice(
      removed.id.isEmpty ? '设备已删除' : '已删除：${removed.customName}',
      RuntimeTaskState.success,
    );
  }

  /// 刷新本地设备状态（P1-FIX：按已存的 qrUrl 逐台查真实状态回填，取代旧 no-op / 更早的 fake 盲切）。
  /// 洗衣机的码固定存在 [LocalDeviceShortcut.qrUrl] → 逐台 `scanWasher(qrUrl)` 得真实
  /// createOrderEnabled/reason → 回填 lastStatus（真实模式=真实后端；模拟模式=fake adapter 的合理值）。
  /// 单台失败不中断整批（保留原状态）；authInvalid 停止并走 RELOG。饮水机无单台状态查询，跳过。
  Future<void> refreshLocalDevices() async {
    if (state.devicesRefresh.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        devicesRefresh: const RuntimeActionStatus(
          state: RuntimeTaskState.loading,
          message: '正在刷新设备状态',
        ),
      ),
    );

    final updated = <LocalDeviceShortcut>[];
    for (final d in state.localDevices) {
      final qr = d.qrUrl;
      if (d.deviceType != LocalDeviceType.washer || qr == null || qr.isEmpty) {
        updated.add(d); // 非洗衣机 / 无码 → 不查，保留原样。
        continue;
      }
      try {
        final program = await ujing.scanWasher(qr);
        // 真实语义（对齐 washer_info_card：createOrderEnabled → 可下单 / 否则 reason 或不可下单）。
        final status = program.createOrderEnabled
            ? '可下单'
            : (program.reason.isEmpty ? '不可下单' : program.reason);
        updated.add(d.copyWith(lastStatus: status));
      } on UjingException catch (e) {
        if (e.authInvalid) {
          // 凭证失效：停止批量刷新，走统一 RELOG 清理 + 引导重登。
          await handleAuthInvalidation(AuthService.ujing);
          return;
        }
        updated.add(d); // 单台失败：保留原状态，不中断其余。
      }
    }

    emit(
      state.copyWith(
        localDevices: updated,
        localDevicesLastRefreshed: formatClockTime(clock.nowMillis()),
        devicesRefresh: const RuntimeActionStatus(
          state: RuntimeTaskState.success,
          message: '设备状态已刷新',
        ),
      ),
    );
    _persistDevices();
  }

  /// 从剪贴板 JSON 导入本地设备列表（M-REAL 导入设备，对齐 legacy importDevices）。
  /// 空/非法 → 错误 notice，不改列表；有效 → 替换 localDevices + 持久化 + 刷新真实状态。
  /// 返回 true=导入成功（shell 据此弹成功/失败 snackbar）。
  Future<bool> importLocalDevicesFromJson(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _emitDevicesNotice('剪贴板为空', RuntimeTaskState.unavailable);
      return false;
    }
    List<LocalDeviceShortcut> decoded;
    try {
      decoded = LocalDeviceCodec.decode(trimmed);
    } catch (_) {
      _emitDevicesNotice('剪贴板不是有效设备列表', RuntimeTaskState.unavailable);
      return false;
    }
    if (decoded.isEmpty) {
      _emitDevicesNotice('剪贴板不是有效设备列表', RuntimeTaskState.unavailable);
      return false;
    }
    deviceSeq = _maxImportedSeq(decoded);
    emit(state.copyWith(localDevices: decoded));
    _persistDevices();
    // 导入后按码查真实状态回填（对齐 legacy 写入后 refreshLocalDevices）。
    await refreshLocalDevices();
    return true;
  }

  /// 导入设备的 sortOrder 最大值 → deviceSeq 起点，避免后续新增撞号。
  int _maxImportedSeq(List<LocalDeviceShortcut> list) {
    var max = deviceSeq;
    for (final d in list) {
      if (d.sortOrder > max) {
        max = d.sortOrder;
      }
    }
    return max;
  }

  /// 持久化当前设备列表（fire-and-forget，对齐 shower798_actions._persist 范式）。
  /// 每次改动 localDevices 后调用；失败不阻塞 UI（真机由用户观察）。
  void _persistDevices() {
    unawaited(devices.saveDevices(state.localDevices));
  }

  void _emitDevicesNotice(String message, RuntimeTaskState taskState) {
    emit(
      state.copyWith(
        devicesRefresh: RuntimeActionStatus(state: taskState, message: message),
      ),
    );
    scheduleDeviceNoticeClear(() {
      emit(state.copyWith(devicesRefresh: const RuntimeActionStatus()));
    });
  }

  /// 取 uuid 末 7 位作为展示设备号（与 legacy 设备号风格接近）。
  String _uuidTail(String qrCode) {
    final idx = qrCode.indexOf('uuid=');
    if (idx < 0) {
      return qrCode.length <= 7 ? qrCode : qrCode.substring(qrCode.length - 7);
    }
    final uuid = qrCode.substring(idx + 5);
    return uuid.length <= 7 ? uuid : uuid.substring(uuid.length - 7);
  }
}
