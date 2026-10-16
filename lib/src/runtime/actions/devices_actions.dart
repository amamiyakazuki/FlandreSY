import '../../data/adapters/ujing_adapter.dart';
import '../../data/device_import.dart';
import '../live_clock.dart';
import '../models/local_device.dart';
import '../runtime_status.dart';
import '../scan_routing.dart';
import '../shui_runtime_base.dart';

mixin DevicesActions on ShuiRuntimeBase {
  Future<DeviceChangeResult> _edit(
    List<LocalDeviceShortcut> Function(List<LocalDeviceShortcut>) update,
    String message, {
    bool replace = false,
  }) async {
    await ready;
    final result = await commitDeviceList(update, replace: replace);
    final feedback = DeviceChangeResult(
        result.success, result.success ? message : result.message);
    _notice(feedback);
    return feedback;
  }

  Future<DeviceChangeResult> addPresetWasherDevice(
          String name, String qrCode) =>
      _add(name, qrCode.trim(), null, 'preset', '海七宿舍');

  Future<DeviceChangeResult> addScannedDeviceFromQr(String qrCode) async {
    ScanRouting routing;
    try {
      routing = classifyScanRouting(qrCode);
    } catch (_) {
      return _reject('二维码格式无效');
    }
    return switch (routing) {
      ScanRoutingWasher() => _add(
          '洗衣机-${_uuidTail(qrCode)}', qrCode.trim(), null, 'scanned', '扫码添加'),
      ScanRoutingDrinkingWater(:final cd) =>
        _add('饮水机-$cd', null, cd.trim(), 'scanned', '扫码添加'),
      ScanRoutingUnknown(:final reason) => _reject(reason),
    };
  }

  Future<DeviceChangeResult> _reject(String message) async {
    final result = DeviceChangeResult(false, message);
    _notice(result);
    return result;
  }

  Future<DeviceChangeResult> _add(
          String name, String? qr, String? cd, String prefix, String store) =>
      _edit((list) {
        if (qr != null && !DeviceImport.validWasherQr(qr)) {
          throw const FormatException('二维码缺少有效设备标识');
        }
        if (qr == null && (cd == null || cd.isEmpty)) {
          throw const FormatException('饮水设备码不能为空');
        }
        if (list.any(
            (d) => qr != null ? d.qrUrl?.trim() == qr : d.cd?.trim() == cd)) {
          throw const FormatException('该设备已在列表中');
        }
        final seq = nextDeviceSequence();
        return [
          ...list,
          LocalDeviceShortcut(
              id: '$prefix-$seq',
              customName: name,
              deviceType: qr != null
                  ? LocalDeviceType.washer
                  : LocalDeviceType.drinkingWater,
              qrUrl: qr,
              cd: cd,
              deviceNo: qr != null ? _uuidTail(qr) : cd,
              storeName: store,
              sortOrder: seq)
        ];
      }, '已添加：$name');

  void _requireUnique(String id, Object? expectedIncarnation) {
    if (!deviceIdIsUnique(id) ||
        (expectedIncarnation != null &&
            !identical(
                state.localDevices.firstWhere((d) => d.id == id).incarnation,
                expectedIncarnation))) {
      throw const FormatException('设备标识为空、重复或已不存在，原记录已保留，请先核对备份');
    }
  }

  Future<DeviceChangeResult> renameLocalDevice(String id, String newName,
          {Object? expectedIncarnation}) =>
      _edit((list) {
        _requireUnique(id, expectedIncarnation);
        final name = newName.trim();
        if (name.isEmpty) throw const FormatException('名称不能为空');
        return list
            .map((d) => d.id == id ? d.copyWith(customName: name) : d)
            .toList();
      }, '设备名称已保存');

  Future<DeviceChangeResult> deleteLocalDevice(String id,
          {Object? expectedIncarnation}) =>
      _edit((list) {
        _requireUnique(id, expectedIncarnation);
        return list.where((d) => d.id != id).toList();
      }, '设备已删除');

  DeviceImportPreview previewDeviceImport(String raw) => DeviceImportPreview(
      DeviceImport.parse(raw), deviceListRevision, state.localDevices.length);

  Future<DeviceChangeResult> confirmDeviceImport(DeviceImportPreview preview) =>
      _edit((_) {
        if (preview.revision != deviceListRevision) {
          throw const FormatException('列表已变化，请重新核对替换数量并确认');
        }
        // 每次替换生成新身份，即使 ID 相同也不能接纳旧刷新响应。
        return preview.devices
            .map((d) => LocalDeviceShortcut(
                  id: d.id,
                  customName: d.customName,
                  deviceType: d.deviceType,
                  qrUrl: d.qrUrl,
                  cd: d.cd,
                  deviceNo: d.deviceNo,
                  storeName: d.storeName,
                  lastStatus: d.lastStatus,
                  sortOrder: d.sortOrder,
                ))
            .toList();
      }, '设备列表已导入；状态尚未查询', replace: true);

  Future<void> refreshLocalDevices() async {
    await ready;
    if (isDisposed || state.devicesRefreshing || ujingAuthChanging) return;
    if (!legacyServiceReady('ujing')) {
      emit(state.copyWith(
          devicesRefresh: const RuntimeActionStatus(
              state: RuntimeTaskState.loginRequired,
              message: '请先重新登录 U 净，再刷新设备')));
      return;
    }
    final epoch = ujingAuthEpoch;
    final targets = List<LocalDeviceShortcut>.of(state.localDevices);
    final replies = <Object, ({String status, String at})>{};
    final failed = <Object>{};
    var skipped = 0;
    emit(state.copyWith(
        devicesRefreshing: true,
        devicesRefresh: const RuntimeActionStatus(
            state: RuntimeTaskState.loading, message: '正在查询设备状态')));
    // 本轮查询未完成前，上轮结果仅为历史；即使保存失败也不能继续计作当前可用。
    invalidateDeviceStatus(clearTimestamp: false);
    try {
      for (final d in targets) {
        if (!isUjingRequestCurrent(epoch)) return;
        if (d.deviceType != LocalDeviceType.washer ||
            !deviceIdIsUnique(d.id) ||
            !DeviceImport.validWasherQr(d.qrUrl)) {
          skipped++;
          continue;
        }
        try {
          final program = await ujing.scanWasher(d.qrUrl!);
          if (!isUjingRequestCurrent(epoch)) return;
          replies[d.incarnation] = (
            status: program.createOrderEnabled
                ? '可下单'
                : program.reason.isEmpty
                    ? '不可下单'
                    : program.reason,
            at: formatClockTime(clock.nowMillis()),
          );
        } on UjingException catch (error) {
          if (!isUjingRequestCurrent(epoch)) return;
          if (error.authInvalid) {
            await handleAuthInvalidation(AuthService.ujing,
                expectedEpoch: epoch);
            return;
          }
          failed.add(d.incarnation);
        } catch (_) {
          if (!isUjingRequestCurrent(epoch)) return;
          failed.add(d.incarnation);
        }
      }
      if (!isUjingRequestCurrent(epoch)) return;
      var success = 0;
      var failure = 0;
      final at = formatClockTime(clock.nowMillis());
      DeviceChangeResult? saved;
      if (replies.isNotEmpty || failed.isNotEmpty) {
        saved = await commitDeviceList((list) {
          if (!isUjingRequestCurrent(epoch)) return null;
          final next = list.map((d) {
            if (!deviceIdIsUnique(d.id)) return d;
            if (replies.containsKey(d.incarnation)) {
              success++;
              return d.copyWith(
                  lastStatus: replies[d.incarnation]!.status,
                  statusConfirmed: true,
                  statusQueryFailed: false,
                  statusCheckedAt: replies[d.incarnation]!.at);
            }
            if (failed.contains(d.incarnation)) {
              failure++;
              return d.copyWith(
                  statusConfirmed: false, statusQueryFailed: true);
            }
            return d;
          }).toList();
          skipped += replies.length + failed.length - success - failure;
          return success + failure == 0 ? null : next;
        });
      }
      if (!isUjingRequestCurrent(epoch)) return;
      final saveFailed =
          saved != null && !saved.success && success + failure > 0;
      emit(state.copyWith(
        localDevicesLastRefreshed: !saveFailed && success > 0 ? at : null,
        devicesRefresh: RuntimeActionStatus(
          state: saveFailed || failure > 0
              ? RuntimeTaskState.failure
              : success > 0
                  ? RuntimeTaskState.success
                  : RuntimeTaskState.unavailable,
          message: saveFailed
              ? saved.message
              : success + failure == 0
                  ? '没有可刷新状态的设备；跳过 $skipped 条（不支持查询、标识异常或已变化）'
                  : '查询成功 $success 条，失败 $failure 条，跳过 $skipped 条${failure > 0 ? '；失败项保留上次结果' : ''}',
        ),
      ));
    } finally {
      emit(state.copyWith(
          devicesRefreshing: false,
          devicesRefresh:
              !isUjingRequestCurrent(epoch) && state.devicesRefresh.isBusy
                  ? const RuntimeActionStatus(
                      state: RuntimeTaskState.unavailable,
                      message: '账号已变化，本次刷新已取消')
                  : null));
    }
  }

  void _notice(DeviceChangeResult result) {
    final notice = RuntimeActionStatus(
        state: result.success
            ? RuntimeTaskState.success
            : RuntimeTaskState.failure,
        message: result.message);
    emit(state.copyWith(devicesNotice: notice));
    // 只清除此条成功通知，不能擦掉后续来自共享写入路径的保存错误。
    scheduleDeviceNoticeClear(() {
      if (result.success && identical(state.devicesNotice, notice)) {
        emit(state.copyWith(devicesNotice: const RuntimeActionStatus()));
      }
    });
  }

  String _uuidTail(String qr) {
    String value = qr;
    try {
      value = Uri.tryParse(qr)?.queryParameters['uuid'] ?? qr;
    } catch (_) {/* 展示兜底；保存前仍须验证。 */}
    return value.length <= 7 ? value : value.substring(value.length - 7);
  }
}
