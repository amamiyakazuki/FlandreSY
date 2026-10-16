import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flandresy/src/data/permission_service.dart';

class TestPermissionBackend extends PermissionBackend {
  TestPermissionBackend({this.target = TargetPlatform.android, this.sdk = 33});
  TargetPlatform target;
  int? sdk;
  Map<Permission, PermissionStatus> values = {};
  List<Permission> checked = [];
  List<List<Permission>> requests = [];
  Future<Map<Permission, PermissionStatus>> Function(List<Permission>)?
      requester;
  bool failRead = false,
      failSettings = false,
      settingsOpened = true,
      locationOn = true;
  int settingsCalls = 0, locationChecks = 0, sdkCalls = 0;
  @override
  TargetPlatform get platform => target;
  @override
  Future<int?> androidSdk() async {
    sdkCalls++;
    return sdk;
  }

  @override
  Future<PermissionStatus> status(Permission permission) async {
    checked.add(permission);
    if (failRead) throw PlatformException(code: 'read');
    return values[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<Map<Permission, PermissionStatus>> request(
      List<Permission> permissions) async {
    requests.add(List.of(permissions));
    final result = await (requester?.call(permissions) ??
        Future.value(
            {for (final p in permissions) p: PermissionStatus.granted}));
    values.addAll(result);
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    if (failSettings) throw StateError('settings');
    return settingsOpened;
  }

  @override
  Future<bool> locationEnabled() async {
    locationChecks++;
    return locationOn;
  }
}

void main() {
  for (final sdk in [24, 30, 31, 32, 33, 36]) {
    test(
        'Android $sdk checks only relevant permissions and requests nothing on check',
        () async {
      final backend = TestPermissionBackend(sdk: sdk);
      final service = ShuiPermissionService(backend: backend);
      final state = await service.check();
      expect(backend.checked, [
        Permission.camera,
        if (sdk <= 30)
          Permission.locationWhenInUse
        else ...[Permission.bluetoothScan, Permission.bluetoothConnect]
      ]);
      expect(backend.requests, isEmpty);
      expect(state.allGranted, isFalse);
      expect((await service.request(ShuiPermissionKind.bluetooth)).granted,
          isTrue);
      expect(
          backend.requests.single,
          sdk <= 30
              ? [Permission.locationWhenInUse]
              : [Permission.bluetoothScan, Permission.bluetoothConnect]);
      expect(backend.requests.expand((p) => p),
          isNot(contains(Permission.notification)));
    });
  }
  test(
      'iOS camera only; disabled control does not check or request Bluetooth/location',
      () async {
    final backend = TestPermissionBackend(target: TargetPlatform.iOS);
    final service = ShuiPermissionService(backend: backend);
    final state = await service.check();
    expect(backend.checked, [Permission.camera]);
    expect(state.status[ShuiPermissionKind.bluetooth]!.status,
        ShuiPermissionStatus.unsupported);
    expect(await service.prepareBluetooth(), iosZhuliUnavailable);
    expect(backend.requests, isEmpty);
    expect(backend.sdkCalls, 0);
    expect((await service.request(ShuiPermissionKind.camera)).granted, isTrue);
    expect((await service.check()).allGranted, isTrue);
  });
  test('unsupported host is not reported as all permissions granted', () async {
    final backend = TestPermissionBackend(target: TargetPlatform.linux);
    final service = ShuiPermissionService(backend: backend);
    expect((await service.check()).allGranted, isFalse);
    expect((await service.request(ShuiPermissionKind.bluetooth)).status,
        ShuiPermissionStatus.unsupported);
    expect(backend.checked, isEmpty);
    expect(backend.requests, isEmpty);
  });
  test('empty state is not granted', () {
    expect(const ShuiPermissionState(status: {}).allGranted, isFalse);
  });
  for (final status in PermissionStatus.values) {
    test('camera status $status has explicit classification', () async {
      final backend = TestPermissionBackend()
        ..values[Permission.camera] = status;
      final result = await ShuiPermissionService(backend: backend)
          .checkKind(ShuiPermissionKind.camera);
      final expected = switch (status) {
        PermissionStatus.granted => ShuiPermissionStatus.granted,
        PermissionStatus.denied => ShuiPermissionStatus.denied,
        PermissionStatus.permanentlyDenied =>
          ShuiPermissionStatus.permanentlyDenied,
        PermissionStatus.restricted => ShuiPermissionStatus.restricted,
        _ => ShuiPermissionStatus.unknown,
      };
      expect(result.status, expected);
    });
  }
  for (final status in [
    PermissionStatus.granted,
    PermissionStatus.permanentlyDenied,
    PermissionStatus.restricted
  ]) {
    test('request does not prompt again for $status', () async {
      final backend = TestPermissionBackend()
        ..values[Permission.camera] = status;
      await ShuiPermissionService(backend: backend)
          .request(ShuiPermissionKind.camera);
      expect(backend.requests, isEmpty);
      expect(backend.settingsCalls, 0);
    });
  }
  test('grant only scan is insufficient; request missing connect only',
      () async {
    final backend = TestPermissionBackend()
      ..values[Permission.bluetoothScan] = PermissionStatus.granted;
    final service = ShuiPermissionService(backend: backend);
    expect((await service.checkKind(ShuiPermissionKind.bluetooth)).granted,
        isFalse);
    expect(
        (await service.request(ShuiPermissionKind.bluetooth)).granted, isTrue);
    expect(backend.requests.single, [Permission.bluetoothConnect]);
  });
  for (final response in [
    <Permission, PermissionStatus>{},
    {Permission.bluetoothScan: PermissionStatus.granted}
  ]) {
    test('empty or partial request response never reports success: $response',
        () async {
      final backend = TestPermissionBackend()
        ..requester = (_) async => response;
      expect(
          (await ShuiPermissionService(backend: backend)
                  .request(ShuiPermissionKind.bluetooth))
              .status,
          ShuiPermissionStatus.unknown);
    });
  }
  test('query failure and request exception are recoverable', () async {
    final backend = TestPermissionBackend()..failRead = true;
    final service = ShuiPermissionService(backend: backend);
    expect((await service.checkKind(ShuiPermissionKind.camera)).status,
        ShuiPermissionStatus.error);
    expect((await service.request(ShuiPermissionKind.camera)).status,
        ShuiPermissionStatus.error);
    backend.failRead = false;
    backend.requester = (_) async => throw StateError('request');
    expect((await service.request(ShuiPermissionKind.camera)).status,
        ShuiPermissionStatus.error);
    backend.requester = null;
    expect((await service.request(ShuiPermissionKind.camera)).granted, isTrue);
  });
  for (final sdk in [null, 0]) {
    test('unknown SDK $sdk does not guess a permission set', () async {
      final backend = TestPermissionBackend(sdk: sdk);
      final service = ShuiPermissionService(backend: backend);
      expect((await service.request(ShuiPermissionKind.bluetooth)).status,
          ShuiPermissionStatus.error);
      expect(backend.requests, isEmpty);
    });
  }
  test(
      'same requests coalesce and different permissions serialize with read after completion',
      () async {
    final gate = Completer<Map<Permission, PermissionStatus>>();
    final backend = TestPermissionBackend()
      ..requester = (permissions) => permissions.contains(Permission.camera)
          ? gate.future
          : Future.value(
              {for (final p in permissions) p: PermissionStatus.granted});
    final service = ShuiPermissionService(backend: backend);
    final first = service.request(ShuiPermissionKind.camera);
    final second = service.request(ShuiPermissionKind.camera);
    final third = service.request(ShuiPermissionKind.bluetooth);
    final read = service.check();
    await Future<void>.delayed(Duration.zero);
    expect(identical(first, second), isTrue);
    expect(backend.requests.length, 1);
    gate.complete({Permission.camera: PermissionStatus.granted});
    expect((await first).granted, isTrue);
    expect((await third).granted, isTrue);
    expect((await read).allGranted, isTrue);
    expect(backend.requests.length, 2);
  });
  for (final mode in ['ok', 'false', 'error']) {
    test('settings result is truthful: $mode', () async {
      final backend = TestPermissionBackend()
        ..settingsOpened = mode == 'ok'
        ..failSettings = mode == 'error';
      final result =
          await ShuiPermissionService(backend: backend).openSettings();
      expect(
          result,
          contains(mode == 'ok'
              ? '已打开'
              : mode == 'false'
                  ? '未能打开'
                  : '失败'));
      expect(backend.settingsCalls, 1);
    });
  }
  for (final sdk in [30, 31]) {
    test('location service is a separate prerequisite only on old Android $sdk',
        () async {
      final backend = TestPermissionBackend(sdk: sdk)..locationOn = false;
      final result =
          await ShuiPermissionService(backend: backend).prepareBluetooth();
      expect(result, sdk <= 30 ? contains('定位服务未开启') : isNull);
      expect(backend.locationChecks, sdk <= 30 ? 1 : 0);
    });
  }
  test('native Android SDK bridge uses integer contract', () async {
    const channel = MethodChannel('flandresy/platform');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'androidSdk');
      return 31;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    expect(await const PermissionBackend().androidSdk(), 31);
  });
}
