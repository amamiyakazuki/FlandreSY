import 'dart:async';
import 'ble_transport.dart';
import 'hotwater_adapter.dart';

Future<String> writeAndAwaitZhuliFrame(
    {required Stream<List<int>> notifications,
    required Future<void> Function() write,
    required List<int> expectedTypes,
    Duration timeout = ZhuliBleContract.responseTimeout}) async {
  final result = Completer<String>();
  final response = result.future.timeout(timeout,
      onTimeout: () => throw const HotwaterException('等待 BLE 响应超时'));
  final subscription = notifications.listen((bytes) {
    if (result.isCompleted) return;
    final frame = ZhuliBleContract.bytesToHex(bytes);
    switch (ZhuliBleContract.classifyFrame(frame, expectedTypes)) {
      case ZhuliFrameVerdict.accept:
        result.complete(frame);
      case ZhuliFrameVerdict.errorCrc:
        result.completeError(const HotwaterException('设备返回 CRC 错误（error_crc）'));
      case ZhuliFrameVerdict.ignore:
        break;
    }
  }, onError: (Object error, StackTrace stack) {
    if (!result.isCompleted) result.completeError(error, stack);
  }, onDone: () {
    if (!result.isCompleted) {
      result.completeError(const HotwaterException('蓝牙通知已断开'));
    }
  });
  try {
    // 两条 Future 同时安装错误处理，不让早到 CRC 错误成为未处理异常。
    final values = await Future.wait<String>([
      response,
      Future<void>.sync(write).timeout(timeout).then((_) => ''),
    ], eagerError: true);
    return values.first;
  } finally {
    if (!result.isCompleted) {
      result.completeError(const HotwaterException('BLE 等待已结束'));
    }
    await subscription.cancel();
  }
}
