// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Zhuli BLE (GATT) transport using flutter_blue_plus (no visual constants — protocol only).
// Faithful to legacy LegacyHotwaterActivity.BleDeviceSession: scan by ble_name / ble_mac / name-contains-"XN"
// fallback (8s), connect with 3 retries (1s apart, 10s each), discover service ff12 / write ff01 /
// notify ff02, enable notifications, write-with-response, and await a type-matched notify (index-2 byte).
//
// THIS IS THE ONLY LAYER THAT TOUCHES THE REAL BLE RADIO, and it is NOT verified by Codex (no BLE
// hardware on the build host) — real scan/connect/GATT behavior MUST be verified ON-DEVICE by the user.
// Not enabled by default (main line = FakeHotwaterAdapter; RealZhuliAdapter defaults to SkeletonBleTransport).
//
// 真机接入前提：Android 已声明 BLUETOOTH_SCAN/CONNECT（<31 用 ACCESS_FINE_LOCATION）+ 运行时授权；
// iOS 已声明 NSBluetooth*UsageDescription。蓝牙需已开启。

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_transport.dart';
import 'hotwater_adapter.dart';

/// 真实 Zhuli BLE 传输：基于 flutter_blue_plus 的 [BleTransport] 实现。
class FlutterBluePlusBleTransport implements BleTransport {
  const FlutterBluePlusBleTransport();

  @override
  Future<ZhuliBleConnection> scanAndConnect({
    required String bleName,
    required String bleMac,
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      throw const HotwaterException('本机不支持蓝牙');
    }
    // 等适配器就绪：不能用 adapterStateNow（刚启动是缓存的 unknown，会误报「未开启」）。
    // 订阅 adapterState 流（它会向平台拉真实状态），等 on；容忍瞬时 unknown/turningOn，
    // 只在确凿 off/unavailable/unauthorized 或超时才失败。
    await _ensureAdapterOn();

    final device = await _scanForDevice(bleName: bleName, bleMac: bleMac);
    final services = await _connectWithRetry(device);

    final service = services.firstWhere(
      (s) => _sameUuid(s.uuid.str, ZhuliBleContract.serviceUuid),
      orElse: () => throw const HotwaterException('未找到 Zhuli BLE 服务（ff12）'),
    );
    final write = service.characteristics.firstWhere(
      (c) => _sameUuid(c.uuid.str, ZhuliBleContract.writeUuid),
      orElse: () => throw const HotwaterException('未找到写特征（ff01）'),
    );
    final notify = service.characteristics.firstWhere(
      (c) => _sameUuid(c.uuid.str, ZhuliBleContract.readUuid),
      orElse: () => throw const HotwaterException('未找到通知特征（ff02）'),
    );

    await notify.setNotifyValue(true);
    return _FbpBleConnection(device: device, write: write, notify: notify);
  }

  /// 等蓝牙适配器变 on。用 adapterState 流（会向平台拉真实状态），10s 超时。
  /// 瞬时 unknown/turningOn 继续等；确凿 off/unavailable/unauthorized 立即失败。
  Future<void> _ensureAdapterOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.firstWhere(
        (s) =>
            s == BluetoothAdapterState.on ||
            s == BluetoothAdapterState.off ||
            s == BluetoothAdapterState.unavailable ||
            s == BluetoothAdapterState.unauthorized,
      ).timeout(ZhuliBleContract.connectTimeout);
      if (state != BluetoothAdapterState.on) {
        throw HotwaterException(_adapterStateMessage(state));
      }
    } on HotwaterException {
      rethrow;
    } on TimeoutException {
      throw const HotwaterException('蓝牙未就绪（等待适配器超时，请确认已开启蓝牙）');
    }
  }

  static String _adapterStateMessage(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.off:
        return '蓝牙未开启';
      case BluetoothAdapterState.unauthorized:
        return '蓝牙权限未授予';
      case BluetoothAdapterState.unavailable:
        return '本机蓝牙不可用';
      default:
        return '蓝牙未就绪';
    }
  }

  /// 扫描：名称精确 / mac 不分大小写 / 名称含「XN」fallback（对齐 legacy onScanResult）。
  Future<BluetoothDevice> _scanForDevice({
    required String bleName,
    required String bleMac,
  }) async {
    final completer = Completer<BluetoothDevice>();
    late final StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.device.advName;
        final address = r.device.remoteId.str;
        final nameMatch = bleName.isNotEmpty && bleName == name;
        final macMatch =
            bleMac.isNotEmpty && bleMac.toLowerCase() == address.toLowerCase();
        final fallback = bleName.isEmpty && name.contains('XN');
        if (nameMatch || macMatch || fallback) {
          if (!completer.isCompleted) {
            completer.complete(r.device);
          }
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: ZhuliBleContract.scanTimeout);
      return await completer.future.timeout(
        ZhuliBleContract.scanTimeout,
        onTimeout: () => throw const HotwaterException('未扫描到目标设备（超时）'),
      );
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  /// 连接 + 服务发现，3 次重试（1s 间隔，每次 10s 超时），对齐 legacy connectGattOnce。
  Future<List<BluetoothService>> _connectWithRetry(BluetoothDevice device) async {
    Object? lastError;
    for (var attempt = 0; attempt < ZhuliBleContract.gattRetry; attempt++) {
      try {
        await device.connect(timeout: ZhuliBleContract.connectTimeout);
        return await device.discoverServices();
      } on Exception catch (e) {
        lastError = e;
        try {
          await device.disconnect();
        } on Exception {
          // 忽略断开异常，继续重试。
        }
        if (attempt < ZhuliBleContract.gattRetry - 1) {
          await Future<void>.delayed(ZhuliBleContract.retryDelay);
        }
      }
    }
    throw HotwaterException('BLE 连接失败（已重试 ${ZhuliBleContract.gattRetry} 次）：$lastError');
  }

  /// UUID 比较：忽略大小写（flutter_blue_plus 可能返回 16-bit 短式，故也比末段）。
  static bool _sameUuid(String a, String full) {
    final la = a.toLowerCase();
    final lf = full.toLowerCase();
    return la == lf || lf.contains(la) || la.contains(lf);
  }
}

/// 一条已连接的 GATT 会话。writeHex 写 write 特征；awaitNotify 从 notify 广播流按类型过滤。
class _FbpBleConnection implements ZhuliBleConnection {
  _FbpBleConnection({
    required this.device,
    required this.write,
    required this.notify,
  });

  final BluetoothDevice device;
  final BluetoothCharacteristic write;
  final BluetoothCharacteristic notify;

  @override
  Future<void> writeHex(String hex) async {
    final bytes = ZhuliBleContract.hexToBytes(hex);
    // 对齐 legacy WRITE_TYPE_DEFAULT（write-with-response）。
    await write.write(bytes);
  }

  @override
  Future<String> awaitNotify({required List<int> expectedTypes}) async {
    final completer = Completer<String>();
    late final StreamSubscription<List<int>> sub;
    sub = notify.onValueReceived.listen((value) {
      final hex = ZhuliBleContract.bytesToHex(value);
      final verdict = ZhuliBleContract.classifyFrame(hex, expectedTypes);
      switch (verdict) {
        case ZhuliFrameVerdict.errorCrc:
          if (!completer.isCompleted) {
            completer.completeError(
              const HotwaterException('设备返回 CRC 错误（error_crc）'),
            );
          }
        case ZhuliFrameVerdict.accept:
          if (!completer.isCompleted) {
            completer.complete(hex);
          }
        case ZhuliFrameVerdict.ignore:
          // 不足 3 字节或非期望类型（如穿插的 set_rate/history 帧）→ 继续等待。
          break;
      }
    });

    try {
      return await completer.future.timeout(
        ZhuliBleContract.responseTimeout,
        onTimeout: () => throw const HotwaterException('等待 BLE 响应超时'),
      );
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> close() async {
    try {
      await device.disconnect();
    } on Exception {
      // 关闭失败不影响业务流程（真机由用户观察日志）。
    }
  }
}
